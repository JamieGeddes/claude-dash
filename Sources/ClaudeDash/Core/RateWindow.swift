import Foundation

/// Rolling-window token rate. With the default 60s window the value is
/// directly "tokens per minute"; other windows are normalized to per-minute.
struct RateWindow: Sendable {
    private var samples: [(date: Date, tokens: Int)] = []
    let window: TimeInterval

    init(window: TimeInterval = 60) {
        self.window = window
    }

    mutating func add(tokens: Int, at date: Date = Date()) {
        samples.append((date, tokens))
    }

    mutating func tokensPerMinute(at now: Date = Date()) -> Double {
        samples.removeAll { $0.date <= now.addingTimeInterval(-window) }
        let sum = samples.reduce(0) { $0 + $1.tokens }
        return Double(sum) * (60.0 / window)
    }

    mutating func reset() {
        samples.removeAll()
    }
}

/// Auto-ranging for the speedometer: dial face is always 0–10, only the
/// multiplier changes. Steps up immediately when pegged, steps down only after
/// the rate has stayed low for a while (hysteresis prevents flapping).
struct SpeedoScaler: Sendable {
    static let multipliers: [Double] = [1_000, 2_000, 5_000, 10_000, 20_000, 50_000]

    private(set) var index = 0
    private var belowSince: Date?

    var multiplier: Double { Self.multipliers[index] }
    var fullScale: Double { multiplier * 10 }

    /// Returns the active multiplier. `lockedIndex` pins a fixed scale.
    mutating func update(rate: Double, at now: Date = Date(), lockedIndex: Int? = nil) -> Double {
        if let lockedIndex {
            index = min(max(lockedIndex, 0), Self.multipliers.count - 1)
            belowSince = nil
            return multiplier
        }
        while rate > fullScale * 0.95, index < Self.multipliers.count - 1 {
            index += 1
            belowSince = nil
        }
        if index > 0, rate < Self.multipliers[index - 1] * 10 * 0.35 {
            if let since = belowSince {
                if now.timeIntervalSince(since) > 30 {
                    index -= 1
                    belowSince = nil
                }
            } else {
                belowSince = now
            }
        } else {
            belowSince = nil
        }
        return multiplier
    }
}
