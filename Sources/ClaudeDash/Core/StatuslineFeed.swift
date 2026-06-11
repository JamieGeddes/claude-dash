import Foundation

/// Reads rate-limit data from the statusline JSON the forwarder script writes.
/// Watches the Application Support *directory* (the file itself is replaced by
/// rename, which would invalidate a file-level watch).
@MainActor
final class StatuslineFeed {
    static let filename = "statusline.json"

    private let directory: URL
    private let fileURL: URL
    private let model: DashboardModel
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var staleTimer: Timer?
    private var lastModified: Date?

    private static let staleAfter: TimeInterval = 10 * 60

    init(directory: URL, model: DashboardModel) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent(Self.filename)
        self.model = model
    }

    func start() {
        readIfChanged(force: true)

        dirFD = open(directory.path, O_EVTONLY)
        if dirFD >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFD,
                eventMask: [.write],
                queue: .main
            )
            source.setEventHandler { [weak self] in self?.readIfChanged(force: false) }
            source.setCancelHandler { [fd = dirFD] in close(fd) }
            source.resume()
            dirSource = source
        }

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.readIfChanged(force: false)
                self?.updateStaleness()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        staleTimer = timer
    }

    func stop() {
        dirSource?.cancel()
        dirSource = nil
        staleTimer?.invalidate()
        staleTimer = nil
    }

    private func readIfChanged(force: Bool) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modified = attrs?[.modificationDate] as? Date
        guard force || modified != lastModified else { return }
        lastModified = modified

        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            updateStaleness()
            return
        }
        let limits = root["rate_limits"] as? [String: Any]
        model.fiveHour = Self.parseWindow(limits?["five_hour"]) ?? model.fiveHour
        model.sevenDay = Self.parseWindow(limits?["seven_day"]) ?? model.sevenDay
        updateStaleness()
    }

    private func updateStaleness() {
        guard let modified = lastModified else {
            model.fuelStale = model.fiveHour != nil || model.sevenDay != nil
            return
        }
        model.fuelStale = Date().timeIntervalSince(modified) > Self.staleAfter
    }

    private static func parseWindow(_ raw: Any?) -> RateLimitWindow? {
        guard let dict = raw as? [String: Any] else { return nil }
        guard let used = doubleValue(dict["used_percentage"]) ?? doubleValue(dict["utilization"]) else {
            return nil
        }
        var resetsAt: Date?
        if let epoch = doubleValue(dict["resets_at"]) {
            resetsAt = Date(timeIntervalSince1970: epoch)
        } else if let iso = dict["resets_at"] as? String {
            resetsAt = ISO8601DateFormatter().date(from: iso)
        }
        // A window that has already reset is effectively full again.
        if let resetsAt, resetsAt < Date() {
            return RateLimitWindow(usedPercentage: 0, resetsAt: resetsAt)
        }
        return RateLimitWindow(usedPercentage: used, resetsAt: resetsAt)
    }

    private static func doubleValue(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let n = raw as? NSNumber { return n.doubleValue }
        return nil
    }
}
