import XCTest
@testable import ClaudeDash

@MainActor
final class StatuslineInstallerTests: XCTestCase {
    private var configDir: URL!
    private var scriptDir: URL!

    override func setUpWithError() throws {
        configDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-config-\(UUID().uuidString)")
        scriptDir = configDir.appendingPathComponent("scripts")
        try FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: configDir)
    }

    private var settingsURL: URL { configDir.appendingPathComponent("settings.json") }
    private var backupURL: URL { configDir.appendingPathComponent("settings.json.claude-dash.bak") }

    private func readSettings() throws -> [String: Any] {
        let data = try Data(contentsOf: settingsURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testInstallIntoExistingSettingsPreservesKeysAndBacksUp() throws {
        let original = #"{"model":"claude-fable-5[1m]","effortLevel":"high","env":{"FOO":"1"}}"#
        try original.write(to: settingsURL, atomically: true, encoding: .utf8)

        try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir)

        let settings = try readSettings()
        XCTAssertEqual(settings["model"] as? String, "claude-fable-5[1m]")
        XCTAssertEqual(settings["effortLevel"] as? String, "high")
        XCTAssertEqual((settings["env"] as? [String: Any])?["FOO"] as? String, "1")

        let statusLine = try XCTUnwrap(settings["statusLine"] as? [String: Any])
        XCTAssertEqual(statusLine["type"] as? String, "command")
        // Must be shell-quoted: Claude Code runs this through sh, and the real
        // install path contains a space ("Application Support").
        XCTAssertEqual(statusLine["command"] as? String, StatuslineInstaller.installedCommand(scriptDir: scriptDir))

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), original)

        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .installed)

        // Forwarder script exists and is executable.
        let attrs = try FileManager.default.attributesOfItem(atPath: StatuslineInstaller.scriptURL(scriptDir: scriptDir).path)
        let perms = try XCTUnwrap(attrs[.posixPermissions] as? NSNumber)
        XCTAssertEqual(perms.intValue & 0o111, 0o111)
    }

    func testInstallWithNoSettingsFileCreatesOne() throws {
        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .notInstalled)
        try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir)
        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .installed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testUninstallRemovesOnlyOurEntry() throws {
        try #"{"model":"opus"}"#.write(to: settingsURL, atomically: true, encoding: .utf8)
        try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir)
        try StatuslineInstaller.uninstall(configDir: configDir, scriptDir: scriptDir)

        let settings = try readSettings()
        XCTAssertNil(settings["statusLine"])
        XCTAssertEqual(settings["model"] as? String, "opus")
        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .notInstalled)
    }

    func testForeignStatuslineIsChainedAndRestoredOnUninstall() throws {
        let foreign = #"{"statusLine":{"type":"command","command":"/usr/local/bin/my-status"}}"#
        try foreign.write(to: settingsURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir),
            .foreign(command: "/usr/local/bin/my-status")
        )

        try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir)
        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .installed)

        // The chained script pipes the JSON through to the original command.
        let script = try String(contentsOf: StatuslineInstaller.scriptURL(scriptDir: scriptDir), encoding: .utf8)
        XCTAssertTrue(script.contains("/usr/local/bin/my-status"))

        try StatuslineInstaller.uninstall(configDir: configDir, scriptDir: scriptDir)
        let settings = try readSettings()
        let restored = try XCTUnwrap(settings["statusLine"] as? [String: Any])
        XCTAssertEqual(restored["command"] as? String, "/usr/local/bin/my-status")
    }

    func testUninstallLeavesForeignStatuslineAlone() throws {
        let foreign = #"{"statusLine":{"type":"command","command":"/bin/other"}}"#
        try foreign.write(to: settingsURL, atomically: true, encoding: .utf8)
        try StatuslineInstaller.uninstall(configDir: configDir, scriptDir: scriptDir)
        let settings = try readSettings()
        XCTAssertEqual((settings["statusLine"] as? [String: Any])?["command"] as? String, "/bin/other")
    }

    func testInstalledCommandExecutesDespiteSpacesInPath() throws {
        // scriptDir deliberately contains a space, like the real install path.
        let spacedDir = configDir.appendingPathComponent("App Support")
        try FileManager.default.createDirectory(at: spacedDir, withIntermediateDirectories: true)
        try StatuslineInstaller.install(configDir: configDir, scriptDir: spacedDir)

        let settings = try readSettings()
        let command = try XCTUnwrap((settings["statusLine"] as? [String: Any])?["command"] as? String)

        // Execute exactly as Claude Code does: sh -c "<command>", JSON on stdin.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["HOME": configDir.path], uniquingKeysWith: { _, new in new }
        )
        try process.run()
        stdin.fileHandleForWriting.write(Data(#"{"rate_limits":{"five_hour":{"used_percentage":12}}}"#.utf8))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let stored = configDir.appendingPathComponent("Library/Application Support/ClaudeDash/statusline.json")
        let data = try Data(contentsOf: stored)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(parsed["rate_limits"])
    }

    func testLegacyUnquotedEntryIsDetectedAndRepaired() throws {
        // Simulate an install made before quoting was fixed.
        let unquoted = StatuslineInstaller.scriptURL(scriptDir: scriptDir).path
        try JSONSerialization.data(withJSONObject: ["statusLine": ["type": "command", "command": unquoted]])
            .write(to: settingsURL)

        XCTAssertEqual(StatuslineInstaller.status(configDir: configDir, scriptDir: scriptDir), .installed)
        XCTAssertTrue(StatuslineInstaller.needsRepair(configDir: configDir, scriptDir: scriptDir))

        try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir)
        XCTAssertFalse(StatuslineInstaller.needsRepair(configDir: configDir, scriptDir: scriptDir))
        let settings = try readSettings()
        XCTAssertEqual(
            (settings["statusLine"] as? [String: Any])?["command"] as? String,
            StatuslineInstaller.installedCommand(scriptDir: scriptDir)
        )
    }

    func testRefusesToModifyCorruptSettings() throws {
        try "not valid json {{{".write(to: settingsURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir))
        // Original file untouched.
        XCTAssertEqual(try String(contentsOf: settingsURL, encoding: .utf8), "not valid json {{{")
    }
}
