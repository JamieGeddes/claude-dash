import XCTest
@testable import ClaudeDash

@MainActor
final class UsageMonitorTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-monitor-\(UUID().uuidString)")
        defaults = UserDefaults(suiteName: "claude-dash-tests")!
        defaults.removePersistentDomain(forName: "claude-dash-tests")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: "claude-dash-tests")
        super.tearDown()
    }

    private func makeStack() -> (OdometerStore, DashboardModel, UsageMonitor, SettingsStore) {
        let store = OdometerStore(directory: tempDir)
        let model = DashboardModel()
        let settings = SettingsStore(defaults: defaults)
        let monitor = UsageMonitor(store: store, model: model, settings: settings)
        return (store, model, monitor, settings)
    }

    private func event(_ requestId: String, session: String = "s1", input: Int = 100, output: Int = 50,
                       cacheRead: Int = 1_000) -> UsageEvent {
        UsageEvent(requestId: requestId, sessionId: session, timestamp: Date(),
                   input: input, output: output, cacheCreation: 0, cacheRead: cacheRead)
    }

    private func update(_ events: [UsageEvent], file: String = "/t.jsonl", offset: UInt64 = 1, live: Bool = true) -> TranscriptWatcher.Update {
        TranscriptWatcher.Update(events: events, file: file, offset: offset, inode: nil, live: live)
    }

    func testDeduplicatesByRequestId() {
        let (_, model, monitor, _) = makeStack()
        monitor.apply(update([event("req_1"), event("req_1"), event("req_2")]))
        // input+output only by default: 2 × 150
        XCTAssertEqual(model.odometerTokens, 300)

        // Same id arriving in a later batch (streamed duplicate) is dropped.
        monitor.apply(update([event("req_2")], offset: 2))
        XCTAssertEqual(model.odometerTokens, 300)
    }

    func testTripFollowsActiveSession() {
        let (_, model, monitor, _) = makeStack()
        monitor.apply(update([event("req_1", session: "a")]))
        XCTAssertEqual(model.tripTokens, 150)
        XCTAssertEqual(model.activeSessionId, "a")

        monitor.apply(update([event("req_2", session: "b"), event("req_3", session: "b")]))
        XCTAssertEqual(model.activeSessionId, "b")
        XCTAssertEqual(model.tripTokens, 300)
        XCTAssertEqual(model.odometerTokens, 450)
    }

    func testCacheToggleIsDisplayOnly() {
        let (_, model, monitor, settings) = makeStack()
        monitor.apply(update([event("req_1", cacheRead: 5_000)]))
        XCTAssertEqual(model.odometerTokens, 150)

        settings.includeCacheTokens = true
        // publishCounters runs via the settings subscription on the next runloop turn.
        let expectation = expectation(description: "republished")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(model.odometerTokens, 5_150)
    }

    func testPersistedSeenRingPreventsRestartDoubleCount() {
        let (store, model, monitor, _) = makeStack()
        monitor.apply(update([event("req_1")]))
        XCTAssertEqual(model.odometerTokens, 150)
        store.saveNow()

        // "Restart": new stack from the same directory replays the same line.
        let store2 = OdometerStore(directory: tempDir)
        let model2 = DashboardModel()
        let settings2 = SettingsStore(defaults: defaults)
        let monitor2 = UsageMonitor(store: store2, model: model2, settings: settings2)
        XCTAssertEqual(model2.odometerTokens, 150)
        monitor2.apply(update([event("req_1")], live: false))
        XCTAssertEqual(model2.odometerTokens, 150)
    }

    func testBackfillDoesNotMoveNeedleButLiveDoes() {
        let (_, model, monitor, _) = makeStack()
        monitor.apply(update([event("req_1", input: 10_000)], live: false))
        XCTAssertEqual(model.tokensPerMinute, 0)

        monitor.apply(update([event("req_2", input: 600)], live: true))
        XCTAssertGreaterThan(model.tokensPerMinute, 0)
    }

    func testMonthlySpendAccumulates() {
        let (store, model, monitor, _) = makeStack()
        // 1M output tokens on current Opus = $25.
        let e = UsageEvent(requestId: "req_s", sessionId: "s1", timestamp: Date(),
                           input: 0, output: 1_000_000, cacheCreation: 0, cacheRead: 0,
                           model: "claude-opus-4-8")
        monitor.apply(update([e]))
        let key = Pricing.monthKey(for: Date())
        XCTAssertEqual(store.state.monthlySpend?[key] ?? 0, 25.0, accuracy: 0.001)
        XCTAssertEqual(model.monthlySpendUSD, 25.0, accuracy: 0.001)
    }

    func testCheckpointStored() {
        let (store, _, monitor, _) = makeStack()
        monitor.apply(update([event("req_1")], file: "/a/b.jsonl", offset: 4_242))
        XCTAssertEqual(store.state.files["/a/b.jsonl"]?.offset, 4_242)
    }
}
