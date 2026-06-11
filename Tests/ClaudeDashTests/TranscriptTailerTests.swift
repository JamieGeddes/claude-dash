import XCTest
@testable import ClaudeDash

final class TranscriptTailerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-dash-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func line(_ requestId: String, tokens: Int = 100) -> String {
        """
        {"type":"assistant","timestamp":"2026-06-11T10:00:00Z","sessionId":"s1","requestId":"\(requestId)","message":{"usage":{"input_tokens":\(tokens),"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
    }

    func testDrainsAppendedLinesIncrementally() throws {
        let url = tempDir.appendingPathComponent("t.jsonl")
        try (line("req_1") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let tailer = TranscriptTailer(url: url, resumeAt: 0)
        let first = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(first.events.map(\.requestId), ["req_1"])

        // No new data: nothing to drain.
        XCTAssertNil(tailer.drain())

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line("req_2") + "\n" + line("req_3") + "\n").utf8))
        try handle.close()

        let second = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(second.events.map(\.requestId), ["req_2", "req_3"])
    }

    func testPartialLineIsNotConsumedUntilComplete() throws {
        let url = tempDir.appendingPathComponent("t.jsonl")
        let full = line("req_1") + "\n"
        let partial = line("req_2")
        let half = String(partial.prefix(40))
        try (full + half).write(to: url, atomically: true, encoding: .utf8)

        let tailer = TranscriptTailer(url: url, resumeAt: 0)
        let first = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(first.events.map(\.requestId), ["req_1"])
        XCTAssertEqual(first.newOffset, UInt64(full.utf8.count))

        // Complete the second line; the tailer re-reads from the boundary.
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((String(partial.dropFirst(40)) + "\n").utf8))
        try handle.close()

        let second = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(second.events.map(\.requestId), ["req_2"])
    }

    func testTruncatedFileRestartsFromZero() throws {
        let url = tempDir.appendingPathComponent("t.jsonl")
        try (line("req_1") + "\n" + line("req_2") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let tailer = TranscriptTailer(url: url, resumeAt: 0)
        _ = tailer.drain()

        // Replace with shorter content (size < committed offset).
        let replacement = line("req_9") + "\n"
        try Data(replacement.utf8).write(to: url) // non-atomic keeps the inode; size shrinks
        let result = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(result.events.map(\.requestId), ["req_9"])
    }

    func testResumeOffsetSkipsAlreadyCountedLines() throws {
        let url = tempDir.appendingPathComponent("t.jsonl")
        let first = line("req_1") + "\n"
        try (first + line("req_2") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value

        let tailer = TranscriptTailer(url: url, resumeAt: UInt64(first.utf8.count), inode: inode)
        let result = try XCTUnwrap(tailer.drain())
        XCTAssertEqual(result.events.map(\.requestId), ["req_2"])
    }
}
