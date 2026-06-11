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
        XCTAssertEqual(statusLine["command"] as? String, StatuslineInstaller.scriptURL(scriptDir: scriptDir).path)

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

    func testRefusesToModifyCorruptSettings() throws {
        try "not valid json {{{".write(to: settingsURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try StatuslineInstaller.install(configDir: configDir, scriptDir: scriptDir))
        // Original file untouched.
        XCTAssertEqual(try String(contentsOf: settingsURL, encoding: .utf8), "not valid json {{{")
    }
}
