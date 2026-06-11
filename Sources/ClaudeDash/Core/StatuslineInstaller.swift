import Foundation

/// Installs/removes the statusline forwarder that feeds the fuel gauge.
/// This is the only component that touches the user's Claude Code config, so
/// every write is: backup first, merge only the statusLine key, atomic rename.
@MainActor
enum StatuslineInstaller {
    enum Status: Equatable {
        case notInstalled
        case installed
        case foreign(command: String) // some other statusline is configured
    }

    enum InstallerError: LocalizedError {
        case unreadableSettings
        case unwritableSettings(underlying: String)

        var errorDescription: String? {
            switch self {
            case .unreadableSettings:
                return "Could not parse ~/.claude/settings.json — refusing to modify it."
            case .unwritableSettings(let detail):
                return "Could not write settings.json: \(detail)"
            }
        }
    }

    static func scriptURL(scriptDir: URL = Paths.appSupportDir) -> URL {
        scriptDir.appendingPathComponent("statusline-forwarder.sh")
    }

    /// Claude Code executes statusline commands through the shell, so the
    /// path must be quoted — Application Support contains a space.
    static func installedCommand(scriptDir: URL = Paths.appSupportDir) -> String {
        shellQuote(scriptURL(scriptDir: scriptDir).path)
    }

    private static func isOurCommand(_ command: String, scriptDir: URL) -> Bool {
        command == installedCommand(scriptDir: scriptDir)
            || command == scriptURL(scriptDir: scriptDir).path // legacy unquoted form
    }

    /// True when our entry is present but in the legacy unquoted form, which
    /// the shell mis-parses because of the space in "Application Support".
    static func needsRepair(configDir: URL, scriptDir: URL = Paths.appSupportDir) -> Bool {
        guard let settings = readSettings(configDir: configDir),
              let statusLine = settings["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String else { return false }
        return command == scriptURL(scriptDir: scriptDir).path
            && command != installedCommand(scriptDir: scriptDir)
    }

    private static func originalCommandURL(scriptDir: URL) -> URL {
        scriptDir.appendingPathComponent("statusline-original.json")
    }

    static func settingsURL(configDir: URL) -> URL {
        configDir.appendingPathComponent("settings.json")
    }

    static func status(configDir: URL, scriptDir: URL = Paths.appSupportDir) -> Status {
        guard let settings = readSettings(configDir: configDir),
              let statusLine = settings["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String else {
            return .notInstalled
        }
        return isOurCommand(command, scriptDir: scriptDir) ? .installed : .foreign(command: command)
    }

    static func install(configDir: URL, scriptDir: URL = Paths.appSupportDir) throws {
        let settingsURL = settingsURL(configDir: configDir)
        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            guard let parsed = readSettings(configDir: configDir) else {
                throw InstallerError.unreadableSettings
            }
            settings = parsed
            let backupURL = configDir.appendingPathComponent("settings.json.claude-dash.bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: settingsURL, to: backupURL)
        }

        // If a different statusline is configured, remember it and chain to it
        // so the user keeps their existing display.
        var chainedCommand: String?
        if let existing = settings["statusLine"] as? [String: Any],
           let command = existing["command"] as? String,
           !isOurCommand(command, scriptDir: scriptDir) {
            chainedCommand = command
            let record = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted])
            try? record.write(to: originalCommandURL(scriptDir: scriptDir), options: .atomic)
        }

        try writeForwarderScript(chainedCommand: chainedCommand, scriptDir: scriptDir)

        settings["statusLine"] = ["type": "command", "command": installedCommand(scriptDir: scriptDir)]
        try writeSettings(settings, to: settingsURL)
    }

    static func uninstall(configDir: URL, scriptDir: URL = Paths.appSupportDir) throws {
        let settingsURL = settingsURL(configDir: configDir)
        guard var settings = readSettings(configDir: configDir) else {
            throw InstallerError.unreadableSettings
        }
        guard let statusLine = settings["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String,
              isOurCommand(command, scriptDir: scriptDir) else {
            return // not ours; leave untouched
        }
        if let data = try? Data(contentsOf: originalCommandURL(scriptDir: scriptDir)),
           let original = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings["statusLine"] = original
        } else {
            settings.removeValue(forKey: "statusLine")
        }
        try writeSettings(settings, to: settingsURL)
        try? FileManager.default.removeItem(at: originalCommandURL(scriptDir: scriptDir))
        try? FileManager.default.removeItem(at: scriptURL(scriptDir: scriptDir))
    }

    // MARK: - Helpers

    private static func readSettings(configDir: URL) -> [String: Any]? {
        let url = settingsURL(configDir: configDir)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func writeSettings(_ settings: [String: Any], to url: URL) throws {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: settings,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
        } catch {
            throw InstallerError.unwritableSettings(underlying: error.localizedDescription)
        }
    }

    private static func writeForwarderScript(chainedCommand: String?, scriptDir: URL) throws {
        let json = "\"$d/\(StatuslineFeed.filename)\""
        var script = """
        #!/bin/sh
        # claude-dash statusline forwarder — written by ClaudeDash.app.
        # Receives Claude Code statusline JSON on stdin and stores it where the
        # dashboard app reads it. Safe to delete; reinstall from ClaudeDash settings.
        d="$HOME/Library/Application Support/ClaudeDash"
        mkdir -p "$d"
        t="$d/statusline.json.tmp.$$"
        cat > "$t" && mv -f "$t" \(json)

        """
        if let chainedCommand {
            script += """
            exec /bin/sh -c \(shellQuote(chainedCommand)) < \(json)

            """
        } else {
            script += """
            printf 'claude-dash'

            """
        }
        let url = scriptURL(scriptDir: scriptDir)
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
