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
