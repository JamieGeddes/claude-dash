import XCTest
@testable import ClaudeDash

final class TranscriptParserTests: XCTestCase {
    // Mirrors the real transcript shape (extra fields included to prove the
    // minimal decoder ignores them).
    private func assistantLine(
        requestId: String = "req_011Test",
        sessionId: String = "45003107-7b72-4698-b589-b81f724173af",
        input: Int = 4685,
        output: Int = 2424
    ) -> String {
        """
        {"type":"assistant","timestamp":"2026-06-11T21:34:31.727Z","sessionId":"\(sessionId)","requestId":"\(requestId)","isSidechain":false,"message":{"id":"msg_x","role":"assistant","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":\(input),"cache_creation_input_tokens":3909,"cache_read_input_tokens":16528,"output_tokens":\(output),"service_tier":"standard","cache_creation":{"ephemeral_1h_input_tokens":3909,"ephemeral_5m_input_tokens":0}}}}
        """
    }

    func testParsesAssistantLine() throws {
        let event = try XCTUnwrap(TranscriptParser.parse(line: Data(assistantLine().utf8)))
        XCTAssertEqual(event.requestId, "req_011Test")
        XCTAssertEqual(event.sessionId, "45003107-7b72-4698-b589-b81f724173af")
        XCTAssertEqual(event.input, 4685)
        XCTAssertEqual(event.output, 2424)
        XCTAssertEqual(event.cacheCreation, 3909)
        XCTAssertEqual(event.cacheRead, 16528)
        XCTAssertEqual(event.tokens(includingCache: false), 4685 + 2424)
        XCTAssertEqual(event.tokens(includingCache: true), 4685 + 2424 + 3909 + 16528)

        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: event.timestamp)
        components.calendar = calendar
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.hour, 21)
    }

    func testIgnoresNonAssistantLines() {
        let user = #"{"type":"user","sessionId":"s","message":{"role":"user","content":"hello"}}"#
        XCTAssertNil(TranscriptParser.parse(line: Data(user.utf8)))

        let summary = #"{"type":"summary","summary":"usage requestId things"}"#
        XCTAssertNil(TranscriptParser.parse(line: Data(summary.utf8)))
    }

    func testIgnoresAssistantWithoutUsageOrRequestId() {
        let noUsage = #"{"type":"assistant","requestId":"req_1","sessionId":"s","message":{"role":"assistant"}}"#
        XCTAssertNil(TranscriptParser.parse(line: Data(noUsage.utf8)))

        let noRequestId = #"{"type":"assistant","sessionId":"s","message":{"usage":{"input_tokens":1,"output_tokens":2}}}"#
        XCTAssertNil(TranscriptParser.parse(line: Data(noRequestId.utf8)))
    }

    func testIgnoresMalformedLine() {
        XCTAssertNil(TranscriptParser.parse(line: Data(#"{"requestId": "usage" broken"#.utf8)))
        XCTAssertNil(TranscriptParser.parse(line: Data()))
    }

    func testParsesSubagentSidechainLine() throws {
        let line = """
        {"parentUuid":"abc","isSidechain":true,"type":"assistant","timestamp":"2026-06-11T10:00:00Z","sessionId":"parent-session","requestId":"req_sub1","message":{"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":0,"cache_read_input_tokens":5}}}
        """
        let event = try XCTUnwrap(TranscriptParser.parse(line: Data(line.utf8)))
        XCTAssertEqual(event.sessionId, "parent-session")
        XCTAssertEqual(event.tokens(includingCache: false), 30)
    }
}
