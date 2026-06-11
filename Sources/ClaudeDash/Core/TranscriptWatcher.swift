import Foundation
import CoreServices

/// Watches the Claude Code projects tree for transcript appends.
/// One recursive FSEvents stream covers session transcripts and the nested
/// `<session>/subagents/*.jsonl` files; a 2s stat-poll over known files covers
/// coalesced/dropped FSEvents, and a 30s rescan discovers anything missed.
final class TranscriptWatcher: @unchecked Sendable {
    struct Update: Sendable {
        let events: [UsageEvent]
        let file: String
        let offset: UInt64
        let inode: UInt64?
        let live: Bool
    }

    private let projectsDir: URL
    private let resumeCheckpoints: [String: FileCheckpoint]
    private let onUpdate: @Sendable (Update) -> Void
    private let queue = DispatchQueue(label: "com.clumsypenguin.claudedash.watcher", qos: .utility)

    private var tailers: [String: TranscriptTailer] = [:]
    private var streamRef: FSEventStreamRef?
    private var pollTimer: DispatchSourceTimer?
    private var rescanTimer: DispatchSourceTimer?
    private var started = false

    init(projectsDir: URL,
         resumeCheckpoints: [String: FileCheckpoint],
         onUpdate: @escaping @Sendable (Update) -> Void) {
        self.projectsDir = projectsDir
        self.resumeCheckpoints = resumeCheckpoints
        self.onUpdate = onUpdate
    }

    func start() {
        queue.async { [self] in
            guard !started else { return }
            started = true
            scanTree(live: false)
            startFSEvents()
            startTimers()
        }
    }

    func stop() {
        queue.sync { [self] in
            if let stream = streamRef {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                streamRef = nil
            }
            pollTimer?.cancel()
            rescanTimer?.cancel()
            pollTimer = nil
            rescanTimer = nil
            started = false
        }
    }

    // MARK: - Discovery

    private static func isTranscript(_ path: String) -> Bool {
        path.hasSuffix(".jsonl") && !path.contains("/tool-results/")
    }

    private func scanTree(live: Bool) {
        guard let enumerator = FileManager.default.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator {
            let path = url.path
            if path.hasSuffix("/tool-results") {
                enumerator.skipDescendants()
                continue
            }
            if Self.isTranscript(path) {
                drainFile(path: path, live: live)
            }
        }
    }

    private func tailer(for path: String) -> TranscriptTailer {
        if let existing = tailers[path] { return existing }
        let checkpoint = resumeCheckpoints[path]
        let tailer = TranscriptTailer(
            url: URL(fileURLWithPath: path),
            resumeAt: checkpoint?.offset ?? 0,
            inode: checkpoint?.inode
        )
        tailers[path] = tailer
        return tailer
    }

    private func drainFile(path: String, live: Bool) {
        let tailer = tailer(for: path)
        guard let result = tailer.drain() else { return }
        onUpdate(Update(
            events: result.events,
            file: path,
            offset: result.newOffset,
            inode: result.inode,
            live: live
        ))
    }

    // MARK: - FSEvents

    private func startFSEvents() {
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            watcher.handleFSEvents(paths: Array(paths.prefix(numEvents)))
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [projectsDir.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        streamRef = stream
    }

    /// Runs on `queue` (the stream is scheduled there).
    private func handleFSEvents(paths: [String]) {
        for path in paths {
            if Self.isTranscript(path) {
                drainFile(path: path, live: true)
            } else if path.hasSuffix(".jsonl") {
                continue // tool-results transcript artifacts
            } else {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue,
                   !path.contains("/tool-results") {
                    scanSubtree(at: path)
                }
            }
        }
    }

    private func scanSubtree(at path: String) {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator {
            if url.path.hasSuffix("/tool-results") {
                enumerator.skipDescendants()
                continue
            }
            if Self.isTranscript(url.path) {
                drainFile(path: url.path, live: true)
            }
        }
    }

    // MARK: - Fallback polling

    private func startTimers() {
        let poll = DispatchSource.makeTimerSource(queue: queue)
        poll.schedule(deadline: .now() + 2, repeating: 2)
        poll.setEventHandler { [weak self] in
            guard let self else { return }
            for (path, tailer) in tailers {
                if let size = tailer.currentSize(), size != tailer.committedOffset {
                    drainFile(path: path, live: true)
                }
            }
        }
        poll.resume()
        pollTimer = poll

        let rescan = DispatchSource.makeTimerSource(queue: queue)
        rescan.schedule(deadline: .now() + 30, repeating: 30)
        rescan.setEventHandler { [weak self] in
            self?.scanTree(live: true)
        }
        rescan.resume()
        rescanTimer = rescan
    }
}
