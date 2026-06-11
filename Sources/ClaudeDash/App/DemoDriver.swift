import Foundation

/// CLAUDE_DASH_DEMO=1: synthesizes usage events and fuel data so the gauges
/// can be polished without burning real tokens.
@MainActor
final class DemoDriver {
    private let monitor: UsageMonitor
    private let model: DashboardModel
    private var eventTimer: Timer?
    private var fuelTimer: Timer?
    private var counter = 0
    private var fuelUsed: Double = 35

    init(monitor: UsageMonitor, model: DashboardModel) {
        self.monitor = monitor
        self.model = model
    }

    func start() {
        scheduleNextEvent()
        model.fiveHour = RateLimitWindow(usedPercentage: fuelUsed, resetsAt: Date().addingTimeInterval(7_200))
        model.sevenDay = RateLimitWindow(usedPercentage: 58, resetsAt: Date().addingTimeInterval(4 * 86_400))

        let fuel = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                fuelUsed = min(97, fuelUsed + Double.random(in: 0...1.6))
                model.fiveHour = RateLimitWindow(
                    usedPercentage: fuelUsed,
                    resetsAt: Date().addingTimeInterval(7_200)
                )
            }
        }
        RunLoop.main.add(fuel, forMode: .common)
        fuelTimer = fuel
    }

    private func scheduleNextEvent() {
        let timer = Timer(timeInterval: Double.random(in: 0.6...2.8), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                emit()
                scheduleNextEvent()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        eventTimer = timer
    }

    private func emit() {
        counter += 1
        let burst = counter % 17 == 0
        let event = UsageEvent(
            requestId: "demo_\(counter)",
            sessionId: "demo-session-\(counter / 60)", // new "session" every ~60 events
            timestamp: Date(),
            input: Int.random(in: 200...1_500) * (burst ? 4 : 1),
            output: Int.random(in: 100...2_500) * (burst ? 3 : 1),
            cacheCreation: Int.random(in: 0...2_000),
            cacheRead: Int.random(in: 1_000...30_000),
            model: "claude-fable-5"
        )
        monitor.apply(TranscriptWatcher.Update(
            events: [event],
            file: "/demo",
            offset: UInt64(counter),
            inode: nil,
            live: true
        ))
    }
}
