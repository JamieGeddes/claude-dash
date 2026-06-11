import Foundation

/// Published per-model API pricing used to estimate spend from token counts.
/// (Subscription seats aren't billed per token, so for Enterprise users this
/// is an *estimate* of consumption value, not an invoice — rates cached
/// 2026-06.) Cache writes bill at 1.25x input (5-minute TTL) or 2x (1-hour
/// TTL); cache reads at 0.1x input.
enum Pricing {
    struct Rate: Equatable {
        let inputPerMTok: Double
        let outputPerMTok: Double
    }

    /// Longest-prefix-style family matching on the model ID; first hit wins.
    private static let table: [(marker: String, rate: Rate)] = [
        ("fable", Rate(inputPerMTok: 10.0, outputPerMTok: 50.0)),
        ("mythos", Rate(inputPerMTok: 10.0, outputPerMTok: 50.0)),
        ("claude-3-opus", Rate(inputPerMTok: 15.0, outputPerMTok: 75.0)),
        ("opus-4-0", Rate(inputPerMTok: 15.0, outputPerMTok: 75.0)),
        ("opus-4-1", Rate(inputPerMTok: 15.0, outputPerMTok: 75.0)),
        ("opus-4-2", Rate(inputPerMTok: 15.0, outputPerMTok: 75.0)),
        ("opus", Rate(inputPerMTok: 5.0, outputPerMTok: 25.0)),       // 4.5+
        ("claude-3-5-sonnet", Rate(inputPerMTok: 3.0, outputPerMTok: 15.0)),
        ("sonnet", Rate(inputPerMTok: 3.0, outputPerMTok: 15.0)),
        ("claude-3-5-haiku", Rate(inputPerMTok: 0.8, outputPerMTok: 4.0)),
        ("claude-3-haiku", Rate(inputPerMTok: 0.25, outputPerMTok: 1.25)),
        ("haiku", Rate(inputPerMTok: 1.0, outputPerMTok: 5.0)),       // 4.5
    ]

    /// Opus-tier default for unknown models keeps the estimate conservative
    /// without exploding on synthetic/odd model strings.
    private static let fallback = Rate(inputPerMTok: 5.0, outputPerMTok: 25.0)

    static func rate(forModel model: String?) -> Rate {
        guard let model = model?.lowercased() else { return fallback }
        for entry in table where model.contains(entry.marker) {
            return entry.rate
        }
        return fallback
    }

    static func costUSD(of event: UsageEvent) -> Double {
        let rate = rate(forModel: event.model)
        let perTokIn = rate.inputPerMTok / 1_000_000
        let perTokOut = rate.outputPerMTok / 1_000_000

        var cost = Double(event.input) * perTokIn + Double(event.output) * perTokOut
        cost += Double(event.cacheRead) * perTokIn * 0.1

        // Cache writes: 1.25x for 5-minute TTL, 2x for 1-hour TTL. Use the
        // TTL split when the transcript provides it, else assume 1.25x.
        if event.cacheCreation5m + event.cacheCreation1h == event.cacheCreation {
            cost += Double(event.cacheCreation5m) * perTokIn * 1.25
            cost += Double(event.cacheCreation1h) * perTokIn * 2.0
        } else {
            cost += Double(event.cacheCreation) * perTokIn * 1.25
        }
        return cost
    }

    /// Calendar-month bucket key, e.g. "2026-06" (local time zone).
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// First instant of the next calendar month (the quota "reset").
    static func nextMonthStart(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return nil
        }
        return calendar.date(byAdding: .month, value: 1, to: monthStart)
    }
}
