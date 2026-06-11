import Foundation

/// Abstraction over where rate-limit ("fuel") data comes from, so Enterprise
/// orgs can plug in the Admin API while personal plans use the statusline feed.
@MainActor
protocol FuelSource {
    func start()
    func stop()
}

extension StatuslineFeed: FuelSource {}

/// Enterprise stub: will poll GET /v1/organizations/usage_report/messages with
/// an admin API key (sk-ant-admin…) and derive utilization from org limits.
/// Not yet implemented — the settings UI exposes it as "coming soon".
@MainActor
final class AdminAPIFuelSource: FuelSource {
    private let model: DashboardModel

    init(model: DashboardModel) {
        self.model = model
    }

    func start() {
        // Phase 2: poll the Admin API usage report (~5 min data latency) and
        // populate model.fiveHour/sevenDay equivalents for org-level usage.
        model.fiveHour = nil
        model.sevenDay = nil
        model.fuelStale = false
    }

    func stop() {}
}
