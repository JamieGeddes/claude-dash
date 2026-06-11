import Foundation

enum Paths {
    /// Resolution order: explicit settings override, process env, launchctl
    /// (Finder-launched apps don't inherit shell env), then ~/.claude.
    static func claudeConfigDir(override: String? = nil) -> URL {
        if let override, !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        if let value = launchctlGetenv("CLAUDE_CONFIG_DIR"), !value.isEmpty {
            return URL(fileURLWithPath: value)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    static func projectsDir(configDir: URL) -> URL {
        configDir.appendingPathComponent("projects")
    }

    static var appSupportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeDash")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func launchctlGetenv(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["getenv", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
