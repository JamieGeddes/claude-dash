import Foundation

/// One deduplicated, token-incurring API call parsed from a Claude Code transcript.
struct UsageEvent: Equatable, Sendable {
    let requestId: String
    let sessionId: String
    let timestamp: Date
    let input: Int
    let output: Int
    let cacheCreation: Int
    let cacheRead: Int
    /// Model ID (e.g. "claude-fable-5") — drives the cost estimate.
    let model: String?
    /// Cache-write split by TTL when the transcript provides it (5m bills
    /// at 1.25x input, 1h at 2x).
    let cacheCreation5m: Int
    let cacheCreation1h: Int

    init(requestId: String, sessionId: String, timestamp: Date,
         input: Int, output: Int, cacheCreation: Int, cacheRead: Int,
         model: String? = nil, cacheCreation5m: Int = 0, cacheCreation1h: Int = 0) {
        self.requestId = requestId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.input = input
        self.output = output
        self.cacheCreation = cacheCreation
        self.cacheRead = cacheRead
        self.model = model
        self.cacheCreation5m = cacheCreation5m
        self.cacheCreation1h = cacheCreation1h
    }

    func tokens(includingCache: Bool) -> Int {
        let base = input + output
        return includingCache ? base + cacheCreation + cacheRead : base
    }
}

/// Running totals kept as separate components so the cache-token setting is
/// purely a display choice and never requires rescanning transcripts.
struct TokenTotals: Codable, Equatable, Sendable {
    var input = 0
    var output = 0
    var cacheCreation = 0
    var cacheRead = 0

    mutating func add(_ event: UsageEvent) {
        input += event.input
        output += event.output
        cacheCreation += event.cacheCreation
        cacheRead += event.cacheRead
    }

    func tokens(includingCache: Bool) -> Int {
        let base = input + output
        return includingCache ? base + cacheCreation + cacheRead : base
    }
}
