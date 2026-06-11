import XCTest
@testable import ClaudeDash

@MainActor
final class SpendSeederTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-seed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func line(_ requestId: String, output: Int) -> String {
        """
        {"type":"assistant","timestamp":"2026-06-11T10:00:00Z","sessionId":"s1","requestId":"\(requestId)","message":{"model":"claude-opus-4-8","usage":{"input_tokens":0,"output_tokens":\(output),"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
    }

    func testSeedsOnlyCheckpointedByteRanges() throws {
        // Two counted lines + one beyond the checkpoint (not yet counted).
        let counted = line("req_1", output: 1_000_000) + "\n" + line("req_2", output: 1_000_000) + "\n"
        let tail = line("req_3", output: 1_000_000) + "\n"
        let url = tempDir.appendingPathComponent("t.jsonl")
        try (counted + tail).write(to: url, atomically: true, encoding: .utf8)

        var state = DashState()
        state.files[url.path] = FileCheckpoint(offset: UInt64(counted.utf8.count), inode: nil)
        SpendSeeder.seed(state: &state)

        XCTAssertEqual(state.spendSeeded, true)
        // 2M output tokens at $25/MTok = $50 — req_3 is beyond the checkpoint.
        XCTAssertEqual(state.monthlySpend?["2026-06"] ?? 0, 50.0, accuracy: 0.001)
    }

    func testSeedRunsOnceAndSkipsFreshInstalls() {
        var fresh = DashState() // no checkpoints
        SpendSeeder.seed(state: &fresh)
        XCTAssertEqual(fresh.spendSeeded, true)
        XCTAssertNil(fresh.monthlySpend)

        var already = DashState()
        already.spendSeeded = true
        already.files["/nonexistent.jsonl"] = FileCheckpoint(offset: 100, inode: nil)
        SpendSeeder.seed(state: &already)
        XCTAssertNil(already.monthlySpend)
    }

    func testV1StateWithoutSpendFieldsStillDecodes() throws {
        // A v1 state.json (no monthlySpend/spendSeeded keys) must load intact.
        let v1 = """
        {"version":1,
         "totals":{"input":10,"output":20,"cacheCreation":30,"cacheRead":40},
         "files":{"/a.jsonl":{"offset":123}},
         "recentRequestIds":["req_a"],
         "sessions":{},
         "activeSessionId":null}
        """
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try v1.write(to: tempDir.appendingPathComponent("state.json"), atomically: true, encoding: .utf8)

        let store = OdometerStore(directory: tempDir)
        XCTAssertEqual(store.state.totals.input, 10)
        XCTAssertEqual(store.state.files["/a.jsonl"]?.offset, 123)
        XCTAssertNil(store.state.spendSeeded)
        XCTAssertNil(store.state.monthlySpend)
    }
}
