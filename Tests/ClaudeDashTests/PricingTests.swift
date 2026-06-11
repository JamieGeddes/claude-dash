import XCTest
@testable import ClaudeDash

final class PricingTests: XCTestCase {
    private func event(input: Int = 0, output: Int = 0, cacheCreation: Int = 0, cacheRead: Int = 0,
                       model: String?, cache5m: Int = 0, cache1h: Int = 0) -> UsageEvent {
        UsageEvent(requestId: "r", sessionId: "s", timestamp: Date(),
                   input: input, output: output, cacheCreation: cacheCreation, cacheRead: cacheRead,
                   model: model, cacheCreation5m: cache5m, cacheCreation1h: cache1h)
    }

    func testFamilyRates() {
        XCTAssertEqual(Pricing.rate(forModel: "claude-fable-5").inputPerMTok, 10.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-mythos-5").outputPerMTok, 50.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-opus-4-8").inputPerMTok, 5.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-opus-4-1-20250805").inputPerMTok, 15.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-sonnet-4-6").outputPerMTok, 15.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-haiku-4-5-20251001").inputPerMTok, 1.0)
        XCTAssertEqual(Pricing.rate(forModel: "claude-3-5-haiku-20241022").inputPerMTok, 0.8)
        // Unknown and nil fall back to current Opus rates.
        XCTAssertEqual(Pricing.rate(forModel: "something-new").inputPerMTok, 5.0)
        XCTAssertEqual(Pricing.rate(forModel: nil).inputPerMTok, 5.0)
    }

    func testCostWithCacheTTLSplit() {
        // Fable 5: $10/MTok in, $50/MTok out.
        let e = event(input: 1_000_000, output: 100_000, cacheCreation: 200_000,
                      cacheRead: 1_000_000, model: "claude-fable-5",
                      cache5m: 50_000, cache1h: 150_000)
        // input 10.0 + output 5.0 + cacheRead 1.0 (0.1x)
        //  + 5m write 0.625 (1.25x) + 1h write 3.0 (2x) = 19.625
        XCTAssertEqual(Pricing.costUSD(of: e), 19.625, accuracy: 0.0001)
    }

    func testCostWithoutSplitAssumesFiveMinuteWrites() {
        let e = event(input: 0, output: 0, cacheCreation: 1_000_000, cacheRead: 0,
                      model: "claude-opus-4-8")
        // 1M cache-write tokens at $5/MTok x 1.25 = $6.25
        XCTAssertEqual(Pricing.costUSD(of: e), 6.25, accuracy: 0.0001)
    }

    func testMonthKeyAndReset() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let june = DateComponents(calendar: calendar, year: 2026, month: 6, day: 11, hour: 23).date!
        XCTAssertEqual(Pricing.monthKey(for: june, calendar: calendar), "2026-06")

        let reset = Pricing.nextMonthStart(after: june, calendar: calendar)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: reset)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour], [2026, 7, 1, 0])
    }
}
