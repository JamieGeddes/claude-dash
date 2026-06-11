import Foundation

struct FileCheckpoint: Codable, Equatable, Sendable {
    var offset: UInt64
    var inode: UInt64?
}

struct SessionTotals: Codable, Equatable, Sendable {
    var totals = TokenTotals()
    var lastEvent: Date
}

struct DashState: Codable, Sendable {
    var version = 2
    var totals = TokenTotals()
    var files: [String: FileCheckpoint] = [:]
    var recentRequestIds: [String] = []
    var sessions: [String: SessionTotals] = [:]
    var activeSessionId: String?
    /// Estimated $ spend per calendar month ("YYYY-MM"). Optional so v1
    /// state files (pre-spend) still decode without resetting the odometer.
    var monthlySpend: [String: Double]?
    /// True once historical spend has been derived from transcripts already
    /// counted under v1 (see SpendSeeder).
    var spendSeeded: Bool?

    mutating func addSpend(_ usd: Double, monthKey: String) {
        var spend = monthlySpend ?? [:]
        spend[monthKey, default: 0] += usd
        // Keep a year of history; prune the rest.
        if spend.count > 13 {
            for key in spend.keys.sorted().dropLast(13) {
                spend.removeValue(forKey: key)
            }
        }
        monthlySpend = spend
    }
}

/// Persists the odometer state to Application Support. Totals are independent
/// of transcript file presence: Claude Code's 30-day transcript cleanup never
/// rolls the odometer back.
@MainActor
final class OdometerStore {
    private let url: URL
    var state: DashState
    private var saveTask: Task<Void, Never>?

    init(directory: URL, filename: String = "state.json") {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder.decode(DashState.self, from: data) {
            self.state = decoded
        } else {
            self.state = DashState()
        }
    }

    /// Debounced save: bursts of events produce one write.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard let data = try? Self.encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
