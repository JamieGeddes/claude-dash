import AppKit
import SwiftUI
import Combine

/// Owns the whole object graph and the overlay panel lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings = SettingsStore()
    let model = DashboardModel()

    private(set) var store: OdometerStore!
    private(set) var monitor: UsageMonitor!
    private var watcher: TranscriptWatcher?
    private var fuelSource: (any FuelSource)?
    private var demoDriver: DemoDriver?
    private var panel: OverlayPanel?
    private var cancellables: Set<AnyCancellable> = []

    @Published var panelVisible = true

    /// While Settings is open the panel yields its always-on-top level so the
    /// Settings window isn't trapped underneath it.
    var settingsWindowOpen = false {
        didSet { panel?.level = settingsWindowOpen ? .normal : .floating }
    }

    var isDemoMode: Bool {
        ProcessInfo.processInfo.environment["CLAUDE_DASH_DEMO"] == "1"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        FontLoader.registerBundledFonts()
        renderSnapshotIfRequested() // `--snapshot out.png` renders and exits
        runStatuslineCLIIfRequested() // `--install-statusline` / `--uninstall-statusline`

        // Demo mode uses a separate state file so synthetic events never
        // pollute the real odometer.
        store = OdometerStore(
            directory: Paths.appSupportDir,
            filename: isDemoMode ? "state-demo.json" : "state.json"
        )
        monitor = UsageMonitor(store: store, model: model, settings: settings)

        if isDemoMode {
            demoDriver = DemoDriver(monitor: monitor, model: model)
            demoDriver?.start()
        } else {
            // Spend seeding must finish before the watcher starts so seeded
            // ranges and live ingest never overlap (see SpendSeeder).
            var snapshot = store.state
            Task.detached(priority: .utility) { [weak self] in
                SpendSeeder.seed(state: &snapshot)
                let seeded = snapshot
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    store.state.monthlySpend = seeded.monthlySpend
                    store.state.spendSeeded = seeded.spendSeeded
                    store.state.version = seeded.version
                    store.scheduleSave()
                    monitor.refresh()
                    startWatcher()
                    startFuelSource()
                }
            }
        }

        settings.$designId
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildPanel() }
            .store(in: &cancellables)

        settings.$plan
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.startFuelSource() }
            .store(in: &cancellables)

        settings.$configDirOverride
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !isDemoMode else { return }
                startWatcher()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved(_:)),
            name: NSWindow.didMoveNotification,
            object: nil
        )

        repairStatuslineIfNeeded()
        rebuildPanel()

        // Defer the one-time consent prompt so it can never block SwiftUI's
        // scene setup — the menu bar item must exist before any modal runs.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.maybeOfferStatuslineInstall()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.flush()
        watcher?.stop()
    }

    // MARK: - Pipeline

    private func startWatcher() {
        watcher?.stop()
        let configDir = Paths.claudeConfigDir(override: settings.configDirOverride)
        let projectsDir = Paths.projectsDir(configDir: configDir)
        let newWatcher = TranscriptWatcher(
            projectsDir: projectsDir,
            resumeCheckpoints: store.state.files
        ) { [weak self] update in
            Task { @MainActor [weak self] in
                self?.monitor.apply(update)
            }
        }
        watcher = newWatcher
        newWatcher.start()
        // The initial scan runs asynchronously; give it a beat, then settle
        // the active session for the trip display.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.monitor.backfillComplete()
        }
    }

    private func startFuelSource() {
        fuelSource?.stop()
        switch settings.plan {
        case .maxOrPro:
            let feed = StatuslineFeed(directory: Paths.appSupportDir, model: model)
            fuelSource = feed
        case .enterprise:
            fuelSource = AdminAPIFuelSource(model: model)
        }
        fuelSource?.start()
    }

    // MARK: - Panel

    func rebuildPanel() {
        let design = DesignRegistry.design(id: settings.designId)
        let view = PanelChrome(onClose: { [weak self] in self?.hidePanel() }) {
            design.makeView(model: model)
        }

        let oldOrigin = panel?.frame.origin
        panel?.orderOut(nil)
        panel?.close()

        let newPanel = OverlayPanel(
            size: design.preferredSize,
            origin: oldOrigin ?? settings.windowOrigin
        )
        newPanel.contentView = FirstMouseHostingView(rootView: view)
        newPanel.level = settingsWindowOpen ? .normal : .floating
        panel = newPanel
        if panelVisible {
            newPanel.orderFrontRegardless()
        }
    }

    func togglePanel() {
        guard let panel else { return }
        panelVisible.toggle()
        if panelVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func hidePanel() {
        guard panelVisible else { return }
        togglePanel()
    }

    @objc private func windowMoved(_ notification: Notification) {
        guard let moved = notification.object as? OverlayPanel, moved === panel else { return }
        settings.windowOrigin = moved.frame.origin
    }

    // MARK: - Snapshot mode (visual development without screen-recording TCC)

    private func renderSnapshotIfRequested() {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--snapshot"), args.count > flagIndex + 1 else { return }
        let outputPath = args[flagIndex + 1]

        let sample = DashboardModel()
        sample.tokensPerMinute = 6_420
        sample.speedoMultiplier = SpeedoScaler.multipliers[0]
        sample.odometerTokens = 12_345_678
        sample.tripTokens = 48_212
        sample.fiveHour = RateLimitWindow(usedPercentage: 38, resetsAt: Date().addingTimeInterval(2 * 3600 + 840))
        sample.sevenDay = RateLimitWindow(usedPercentage: 61, resetsAt: Date().addingTimeInterval(3 * 86_400))
        if args.contains("--enterprise") {
            sample.plan = .enterprise
            sample.monthlySpendUSD = 1_842.50
            sample.monthlyQuotaUSD = 5_000
            sample.monthResetsAt = Pricing.nextMonthStart()
        }
        if args.contains("--stale") { sample.fuelStale = true }
        if args.contains("--low-fuel") {
            sample.fiveHour = RateLimitWindow(usedPercentage: 91, resetsAt: Date().addingTimeInterval(2_400))
        }

        var designId = settings.designId
        if let designIndex = args.firstIndex(of: "--design"), args.count > designIndex + 1 {
            designId = args[designIndex + 1]
        }
        let design = DesignRegistry.design(id: designId)
        let renderer = ImageRenderer(
            content: design.makeView(model: sample)
                .frame(width: design.preferredSize.width, height: design.preferredSize.height)
        )
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: outputPath))
        }
        exit(0)
    }

    // MARK: - Statusline CLI (scriptable install/uninstall)

    private func runStatuslineCLIIfRequested() {
        let args = CommandLine.arguments
        let install = args.contains("--install-statusline")
        let uninstall = args.contains("--uninstall-statusline")
        guard install || uninstall else { return }
        let configDir = Paths.claudeConfigDir(override: settings.configDirOverride)
        do {
            if install {
                try StatuslineInstaller.install(configDir: configDir)
                settings.statuslinePromptShown = true
                print("statusline installed: \(StatuslineInstaller.scriptURL().path)")
            } else {
                try StatuslineInstaller.uninstall(configDir: configDir)
                print("statusline uninstalled")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    /// Early installs wrote the forwarder path unquoted; the shell mis-parses
    /// the space in "Application Support" and the statusline silently fails.
    /// The user already consented to the install, so rewriting our own entry
    /// into the working quoted form needs no new prompt.
    private func repairStatuslineIfNeeded() {
        guard !isDemoMode else { return }
        let configDir = Paths.claudeConfigDir(override: settings.configDirOverride)
        if StatuslineInstaller.needsRepair(configDir: configDir) {
            try? StatuslineInstaller.install(configDir: configDir)
        }
    }

    // MARK: - First-launch statusline consent

    private func maybeOfferStatuslineInstall() {
        guard !isDemoMode, !settings.statuslinePromptShown, settings.plan == .maxOrPro else { return }
        let configDir = Paths.claudeConfigDir(override: settings.configDirOverride)
        guard StatuslineInstaller.status(configDir: configDir) == .notInstalled else {
            settings.statuslinePromptShown = true
            return
        }
        settings.statuslinePromptShown = true

        let alert = NSAlert()
        alert.messageText = "Enable the fuel gauge?"
        alert.informativeText = """
        The fuel gauge shows how much of your Claude 5-hour and 7-day usage windows \
        remain. To get that data, Claude Dash installs a small statusline script for \
        Claude Code and adds a "statusLine" entry to ~/.claude/settings.json \
        (a backup of the file is made first). You can undo this anytime from Settings.
        """
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try StatuslineInstaller.install(configDir: configDir)
            } catch {
                let failure = NSAlert()
                failure.messageText = "Statusline install failed"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
        }
    }
}
