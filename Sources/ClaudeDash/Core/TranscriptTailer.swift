import Foundation

/// Incrementally reads new complete lines from one transcript file.
/// The committed offset only ever lands on a newline boundary, so a line that
/// is mid-write when we read is simply picked up on the next drain.
final class TranscriptTailer {
    let url: URL
    private(set) var committedOffset: UInt64
    private(set) var inode: UInt64?

    init(url: URL, resumeAt offset: UInt64, inode: UInt64? = nil) {
        self.url = url
        self.committedOffset = offset
        self.inode = inode
    }

    struct DrainResult {
        let events: [UsageEvent]
        let newOffset: UInt64
        let inode: UInt64?
    }

    /// Current size on disk, or nil if the file vanished.
    func currentSize() -> UInt64? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.uint64Value
    }

    func drain() -> DrainResult? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let attrs else { return nil }
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let currentInode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value

        // Truncated or replaced file: start over; the request-id seen-set
        // upstream protects against double counting.
        if size < committedOffset || (inode != nil && currentInode != nil && inode != currentInode) {
            committedOffset = 0
        }
        inode = currentInode
        guard size > committedOffset else { return nil }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: committedOffset)
        } catch { return nil }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        // Only consume through the last newline; a trailing partial line stays
        // unconsumed and is re-read next time.
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return nil }
        let consumed = data[data.startIndex...lastNewline]

        var events: [UsageEvent] = []
        for slice in consumed.split(separator: 0x0A) where !slice.isEmpty {
            if let event = TranscriptParser.parse(line: Data(slice)) {
                events.append(event)
            }
        }

        committedOffset += UInt64(consumed.count)
        return DrainResult(events: events, newOffset: committedOffset, inode: currentInode)
    }
}
