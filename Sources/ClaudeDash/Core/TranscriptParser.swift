import Foundation

/// Parses a single JSONL transcript line into a UsageEvent.
/// Transcript lines can be very large (thinking blocks, tool results), so only
/// the handful of fields we need are decoded.
enum TranscriptParser {
    private struct Line: Decodable {
        let type: String?
        let requestId: String?
        let sessionId: String?
        let timestamp: String?
        let message: Message?

        struct Message: Decodable {
            let usage: Usage?
            let model: String?
        }

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
            let cache_creation: CacheCreation?
        }

        struct CacheCreation: Decodable {
            let ephemeral_5m_input_tokens: Int?
            let ephemeral_1h_input_tokens: Int?
        }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let requestIdMarker = Data("\"requestId\"".utf8)
    private static let usageMarker = Data("\"usage\"".utf8)

    static func parse(line: Data) -> UsageEvent? {
        // Cheap byte-level pre-filter: most lines (user messages, progress,
        // tool results) never reach the JSON decoder.
        guard line.range(of: requestIdMarker) != nil,
              line.range(of: usageMarker) != nil else { return nil }

        guard let decoded = try? JSONDecoder().decode(Line.self, from: line),
              decoded.type == "assistant",
              let requestId = decoded.requestId,
              let sessionId = decoded.sessionId,
              let usage = decoded.message?.usage else { return nil }

        let timestamp = decoded.timestamp.flatMap {
            isoFractional.date(from: $0) ?? isoPlain.date(from: $0)
        } ?? Date()

        return UsageEvent(
            requestId: requestId,
            sessionId: sessionId,
            timestamp: timestamp,
            input: usage.input_tokens ?? 0,
            output: usage.output_tokens ?? 0,
            cacheCreation: usage.cache_creation_input_tokens ?? 0,
            cacheRead: usage.cache_read_input_tokens ?? 0,
            model: decoded.message?.model,
            cacheCreation5m: usage.cache_creation?.ephemeral_5m_input_tokens ?? 0,
            cacheCreation1h: usage.cache_creation?.ephemeral_1h_input_tokens ?? 0
        )
    }
}
