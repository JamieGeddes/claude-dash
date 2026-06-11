import XCTest
@testable import ClaudeDash

@MainActor
final class OdometerStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-store-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testRoundTrip() {
        let store = OdometerStore(directory: tempDir)
        store.state.totals = TokenTotals(input: 10, output: 20, cacheCreation: 30, cacheRead: 40)
        store.state.files["/x.jsonl"] = FileCheckpoint(offset: 123, inode: 456)
        store.state.recentRequestIds = ["req_a", "req_b"]
        store.state.sessions["s1"] = SessionTotals(
            totals: TokenTotals(input: 1, output: 2, cacheCreation: 0, cacheRead: 0),
            lastEvent: Date(timeIntervalSince1970: 1_750_000_000)
        )
        store.state.activeSessionId = "s1"
        store.saveNow()

        let reloaded = OdometerStore(directory: tempDir)
        XCTAssertEqual(reloaded.state.totals, store.state.totals)
        XCTAssertEqual(reloaded.state.files, store.state.files)
        XCTAssertEqual(reloaded.state.recentRequestIds, ["req_a", "req_b"])
        XCTAssertEqual(reloaded.state.activeSessionId, "s1")
        XCTAssertEqual(reloaded.state.sessions["s1"]?.totals.input, 1)
    }

    func testFreshDirectoryStartsEmpty() {
        let store = OdometerStore(directory: tempDir)
        XCTAssertEqual(store.state.totals, TokenTotals())
        XCTAssertTrue(store.state.files.isEmpty)
    }

    func testCorruptStateFileStartsEmpty() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempDir.appendingPathComponent("state.json"))
        let store = OdometerStore(directory: tempDir)
        XCTAssertEqual(store.state.totals, TokenTotals())
    }
}
