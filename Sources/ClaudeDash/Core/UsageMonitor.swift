import Foundation
import Combine

/// State hub: deduplicates usage events, maintains odometer/trip/rate, and
/// publishes into the design-agnostic DashboardModel.
@MainActor
final class UsageMonitor {
    private let store: OdometerStore
    private let model: DashboardModel
    private let settings: SettingsStore

    /// Full set for the process lifetime; only the most recent ~1k persist.
    private var seenRequestIds: Set<String>
    private var seenOrder: [String]
    private var rateWindow = RateWindow()
    private var scaler = SpeedoScaler()
    private var tickTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private static let seenRingSize = 1_000
    private static let sessionRetention: TimeInterval = 24 * 3600

    init(store: OdometerStore, model: DashboardModel, settings: SettingsStore) {
        self.store = store
        self.model = model
        self.settings = settings
        self.seenOrder = store.state.recentRequestIds
        self.seenRequestIds = Set(store.state.recentRequestIds)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.publishCounters() }
            .store(in: &cancellables)

        publishCounters()
        startTicking()
    }

    func apply(_ update: TranscriptWatcher.Update) {
        var counted: [UsageEvent] = []
        for event in update.events where !seenRequestIds.contains(event.requestId) {
            seenRequestIds.insert(event.requestId)
            seenOrder.append(event.requestId)
            counted.append(event)
        }

        let now = Date()
        for event in counted {
            store.state.totals.add(event)
            store.state.addSpend(
                Pricing.costUSD(of: event),
                monthKey: Pricing.monthKey(for: event.timestamp)
            )
            var session = store.state.sessions[event.sessionId]
                ?? SessionTotals(totals: TokenTotals(), lastEvent: event.timestamp)
            session.totals.add(event)
            session.lastEvent = max(session.lastEvent, event.timestamp)
            store.state.sessions[event.sessionId] = session

            if update.live {
                rateWindow.add(tokens: event.tokens(includingCache: settings.includeCacheTokens), at: now)
                store.state.activeSessionId = event.sessionId
            }
        }

        store.state.sessions = store.state.sessions.filter {
            now.timeIntervalSince($0.value.lastEvent) < Self.sessionRetention
        }
        if seenOrder.count > Self.seenRingSize * 2 {
            seenOrder.removeFirst(seenOrder.count - Self.seenRingSize)
        }
        store.state.recentRequestIds = Array(seenOrder.suffix(Self.seenRingSize))
        store.state.files[update.file] = FileCheckpoint(offset: update.offset, inode: update.inode)
        store.scheduleSave()

        if update.live {
            tick()
        }
        publishCounters()
    }

    /// Called once the initial backfill scan has been ingested.
    func backfillComplete() {
        if store.state.activeSessionId == nil {
            store.state.activeSessionId = store.state.sessions
                .max { $0.value.lastEvent < $1.value.lastEvent }?.key
        }
        publishCounters()
    }

    func flush() {
        store.saveNow()
    }

    /// Re-publish after out-of-band state changes (e.g. spend seeding).
    func refresh() {
        publishCounters()
    }

    private func publishCounters() {
        let includeCache = settings.includeCacheTokens
        model.includeCacheTokens = includeCache
        model.plan = settings.plan
        model.odometerTokens = store.state.totals.tokens(includingCache: includeCache)
        model.activeSessionId = store.state.activeSessionId
        if let active = store.state.activeSessionId,
           let session = store.state.sessions[active] {
            model.tripTokens = session.totals.tokens(includingCache: includeCache)
        } else {
            model.tripTokens = 0
        }

        model.monthlySpendUSD = store.state.monthlySpend?[Pricing.monthKey(for: Date())] ?? 0
        model.monthlyQuotaUSD = settings.monthlyQuotaUSD
        model.monthResetsAt = Pricing.nextMonthStart()
    }

    // MARK: - Rate ticking (needle decay)

    private func startTicking() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        let rate = rateWindow.tokensPerMinute()
        if model.tokensPerMinute != rate {
            model.tokensPerMinute = rate
        }
        let multiplier = scaler.update(rate: rate, lockedIndex: settings.speedoScaleLock)
        if model.speedoMultiplier != multiplier {
            model.speedoMultiplier = multiplier
        }
    }
}
