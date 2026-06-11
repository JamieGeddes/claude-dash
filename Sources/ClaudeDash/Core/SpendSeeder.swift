import Foundation

/// One-time upgrade path: states written before monthly spend existed have
/// already token-counted everything up to each file's checkpoint, so those
/// events will never flow through UsageMonitor again. This re-reads exactly
/// the checkpointed byte ranges [0, offset) and derives their spend — events
/// beyond the checkpoints arrive through the normal ingest path, which prices
/// them itself, so there is no overlap and no double counting.
///
/// Must complete before the transcript watcher starts.
enum SpendSeeder {
    static func seed(state: inout DashState) {
        guard state.spendSeeded != true else { return }
        defer { state.spendSeeded = true }
        guard !state.files.isEmpty else { return } // fresh install: nothing pre-counted

        var seen = Set<String>()
        for (path, checkpoint) in state.files {
            guard checkpoint.offset > 0,
                  let handle = FileHandle(forReadingAtPath: path) else { continue }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: Int(checkpoint.offset)), !data.isEmpty else {
                continue
            }
            for slice in data.split(separator: 0x0A) where !slice.isEmpty {
                guard let event = TranscriptParser.parse(line: Data(slice)),
                      !seen.contains(event.requestId) else { continue }
                seen.insert(event.requestId)
                state.addSpend(Pricing.costUSD(of: event), monthKey: Pricing.monthKey(for: event.timestamp))
            }
        }
    }
}
