import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @EnvironmentObject private var settings: SettingsStore

    @State private var statuslineStatus: StatuslineInstaller.Status = .notInstalled
    @State private var statuslineError: String?

    private var configDir: URL {
        Paths.claudeConfigDir(override: settings.configDirOverride)
    }

    var body: some View {
        Form {
            Section("Dashboard") {
                Picker("Design", selection: $settings.designId) {
                    ForEach(DesignRegistry.all, id: \.id) { design in
                        Text(design.displayName).tag(design.id)
                    }
                }
                Picker("Speedometer scale", selection: $settings.speedoScaleLock) {
                    Text("Auto").tag(Int?.none)
                    ForEach(Array(SpeedoScaler.multipliers.enumerated()), id: \.offset) { index, multiplier in
                        Text("0–\(Int(multiplier * 10 / 1000))k tok/min").tag(Int?.some(index))
                    }
                }
                Toggle("Count cache tokens", isOn: $settings.includeCacheTokens)
                Text("When on, cache creation and cache read tokens are included in all dials. Cache reads usually dominate, so totals get much larger.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Plan") {
                Picker("Claude plan", selection: $settings.plan) {
                    ForEach(PlanType.allCases) { plan in
                        Text(plan.displayName).tag(plan)
                    }
                }
                if settings.plan == .enterprise {
                    TextField(
                        "Monthly max spend (USD)",
                        value: $settings.monthlyQuotaUSD,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    Text("Enterprise plans have no personal 5-hour window, so the fuel gauge tracks this monthly budget instead: spend is estimated from this machine's usage (tokens × published API pricing, including cache rates) and resets on the 1st. Set 0 to disable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.plan == .maxOrPro {
                Section("Fuel gauge data (statusline)") {
                    LabeledContent("Status") {
                        switch statuslineStatus {
                        case .installed:
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .notInstalled:
                            Label("Not installed", systemImage: "circle.dashed")
                                .foregroundStyle(.secondary)
                        case .foreign:
                            Label("Another statusline is configured", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                    HStack {
                        Button("Install") { runInstaller { try StatuslineInstaller.install(configDir: configDir) } }
                            .disabled(statuslineStatus == .installed)
                        Button("Uninstall") { runInstaller { try StatuslineInstaller.uninstall(configDir: configDir) } }
                            .disabled(statuslineStatus != .installed)
                    }
                    if case .foreign = statuslineStatus {
                        Text("Installing will keep your existing statusline working: Claude Dash forwards the data to it after recording what the fuel gauge needs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Adds a \"statusLine\" entry to \(configDir.path)/settings.json (backed up first). Claude Code then reports rate-limit usage after every message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let statuslineError {
                        Text(statuslineError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Advanced") {
                TextField("Claude config directory", text: $settings.configDirOverride, prompt: Text("~/.claude"))
                Text("Leave empty unless you use CLAUDE_CONFIG_DIR. Transcripts are read from <config dir>/projects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            refreshStatus()
            appDelegate.settingsWindowOpen = true
        }
        .onDisappear {
            appDelegate.settingsWindowOpen = false
        }
    }

    private func refreshStatus() {
        statuslineStatus = StatuslineInstaller.status(configDir: configDir)
    }

    private func runInstaller(_ action: () throws -> Void) {
        statuslineError = nil
        do {
            try action()
        } catch {
            statuslineError = error.localizedDescription
        }
        refreshStatus()
    }
}
