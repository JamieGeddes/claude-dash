import SwiftUI
import ServiceManagement

@main
struct ClaudeDashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Claude Dash", systemImage: "gauge.with.needle") {
            MenuContent()
                .environmentObject(appDelegate)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate)
                .environmentObject(appDelegate.settings)
        }
    }
}

private struct MenuContent: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        Button(appDelegate.panelVisible ? "Hide Dashboard" : "Show Dashboard") {
            appDelegate.togglePanel()
        }
        SettingsLink {
            Text("Settings…")
        }
        Divider()
        LaunchAtLoginToggle()
        Divider()
        Button("Quit Claude Dash") {
            NSApp.terminate(nil)
        }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: Binding(
            get: { enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    enabled = newValue
                } catch {
                    // Fails outside a proper .app bundle (e.g. `swift run`).
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
        ))
    }
}
