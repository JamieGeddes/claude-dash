import XCTest
@testable import ClaudeDash

@MainActor
final class StatuslineFeedTests: XCTestCase {
    private var tempDir: URL!
    private var model: DashboardModel!
    private var feed: StatuslineFeed!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-feed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        model = DashboardModel()
        feed = StatuslineFeed(directory: tempDir, model: model)
    }

    override func tearDownWithError() throws {
        feed.stop()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeStatusline(_ json: String) throws {
        try json.write(
            to: tempDir.appendingPathComponent(StatuslineFeed.filename),
            atomically: true,
            encoding: .utf8
        )
    }

    func testParsesRateLimitsOnStart() throws {
        let resets = Date().addingTimeInterval(3_600).timeIntervalSince1970
        try writeStatusline("""
        {"session_id":"abc","model":{"id":"claude-fable-5"},
         "rate_limits":{
            "five_hour":{"used_percentage":23.5,"resets_at":\(resets)},
            "seven_day":{"used_percentage":41.2,"resets_at":\(resets + 86_400)}
         }}
        """)
        feed.start()
        XCTAssertEqual(model.fiveHour?.usedPercentage, 23.5)
        XCTAssertEqual(model.fiveHour?.remainingPercentage, 76.5)
        XCTAssertEqual(model.sevenDay?.usedPercentage, 41.2)
        XCTAssertNotNil(model.fiveHour?.resetsAt)
        XCTAssertFalse(model.fuelStale)
    }

    func testExpiredWindowReadsAsFull() throws {
        let past = Date().addingTimeInterval(-60).timeIntervalSince1970
        try writeStatusline(#"{"rate_limits":{"five_hour":{"used_percentage":88,"resets_at":\#(past)}}}"#)
        feed.start()
        XCTAssertEqual(model.fiveHour?.remainingPercentage, 100)
    }

    func testMissingFileLeavesModelEmpty() {
        feed.start()
        XCTAssertNil(model.fiveHour)
        XCTAssertNil(model.sevenDay)
    }

    func testMalformedJSONKeepsPreviousValues() throws {
        try writeStatusline(#"{"rate_limits":{"five_hour":{"used_percentage":10}}}"#)
        feed.start()
        XCTAssertEqual(model.fiveHour?.usedPercentage, 10)
        try writeStatusline("garbage{{{")
        // Direct re-read (the dir watcher needs a runloop spin; call internals via start contract)
        feed.stop()
        feed = StatuslineFeed(directory: tempDir, model: model)
        feed.start()
        XCTAssertEqual(model.fiveHour?.usedPercentage, 10)
    }
}
