import Foundation
import Combine

enum PlanType: String, Codable, CaseIterable, Identifiable {
    case maxOrPro
    case enterprise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .maxOrPro: return "Max / Pro"
        case .enterprise: return "Enterprise"
        }
    }
}

struct RateLimitWindow: Equatable, Sendable {
    var usedPercentage: Double
    var resetsAt: Date?

    var remainingPercentage: Double { max(0, min(100, 100 - usedPercentage)) }
}

/// Design-agnostic view model. The data layer (UsageMonitor, StatuslineFeed)
/// writes here; dashboard designs only ever read from this object, so new
/// designs never touch Core types.
@MainActor
final class DashboardModel: ObservableObject {
    // Speedometer
    @Published var tokensPerMinute: Double = 0
    /// Dial faces read 0–10; full scale = multiplier × 10.
    @Published var speedoMultiplier: Double = SpeedoScaler.multipliers[0]

    // Counters
    @Published var odometerTokens: Int = 0
    @Published var tripTokens: Int = 0
    @Published var activeSessionId: String?

    // Rate-limit windows (Max/Pro personal plans)
    @Published var fiveHour: RateLimitWindow?
    @Published var sevenDay: RateLimitWindow?
    /// True when the statusline feed hasn't updated recently; designs should
    /// render limit gauges dimmed with a staleness cue.
    @Published var fuelStale: Bool = false

    // Monthly spend quota (Enterprise) — estimated $ from local transcripts
    @Published var monthlySpendUSD: Double = 0
    /// 0 = no quota configured.
    @Published var monthlyQuotaUSD: Double = 0
    @Published var monthResetsAt: Date?

    /// Fuel-gauge view of the monthly quota: F = nothing spent, E = quota hit.
    var monthlyQuota: RateLimitWindow? {
        guard monthlyQuotaUSD > 0 else { return nil }
        return RateLimitWindow(
            usedPercentage: min(100, monthlySpendUSD / monthlyQuotaUSD * 100),
            resetsAt: monthResetsAt
        )
    }

    // Configuration designs may reflect
    @Published var plan: PlanType = .maxOrPro
    @Published var includeCacheTokens: Bool = false
}
