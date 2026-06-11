import XCTest
@testable import ClaudeDash

final class RateWindowTests: XCTestCase {
    func testSumsTokensInsideWindow() {
        var window = RateWindow(window: 60)
        let now = Date()
        window.add(tokens: 1_000, at: now.addingTimeInterval(-10))
        window.add(tokens: 500, at: now.addingTimeInterval(-50))
        XCTAssertEqual(window.tokensPerMinute(at: now), 1_500)
    }

    func testExpiresOldSamples() {
        var window = RateWindow(window: 60)
        let now = Date()
        window.add(tokens: 1_000, at: now.addingTimeInterval(-61))
        window.add(tokens: 200, at: now.addingTimeInterval(-5))
        XCTAssertEqual(window.tokensPerMinute(at: now), 200)
        XCTAssertEqual(window.tokensPerMinute(at: now.addingTimeInterval(56)), 0)
    }

    func testNormalizesToPerMinute() {
        var window = RateWindow(window: 30)
        let now = Date()
        window.add(tokens: 300, at: now)
        XCTAssertEqual(window.tokensPerMinute(at: now), 600)
    }

    func testScalerStepsUpImmediatelyAndDownWithHysteresis() {
        var scaler = SpeedoScaler()
        let start = Date()
        XCTAssertEqual(scaler.multiplier, 1_000)

        // Pegged needle: jumps as many steps as needed at once.
        _ = scaler.update(rate: 25_000, at: start)
        XCTAssertEqual(scaler.multiplier, 5_000)

        // Low rate must persist >30s before stepping down.
        _ = scaler.update(rate: 100, at: start.addingTimeInterval(1))
        XCTAssertEqual(scaler.multiplier, 5_000)
        _ = scaler.update(rate: 100, at: start.addingTimeInterval(20))
        XCTAssertEqual(scaler.multiplier, 5_000)
        _ = scaler.update(rate: 100, at: start.addingTimeInterval(33))
        XCTAssertEqual(scaler.multiplier, 2_000)
    }

    func testScalerLockPinsScale() {
        var scaler = SpeedoScaler()
        _ = scaler.update(rate: 999_999, lockedIndex: 0)
        XCTAssertEqual(scaler.multiplier, 1_000)
        _ = scaler.update(rate: 0, lockedIndex: 5)
        XCTAssertEqual(scaler.multiplier, 50_000)
    }
}
