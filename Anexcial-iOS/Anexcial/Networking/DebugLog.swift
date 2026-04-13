import Foundation

/// Sends a single NDJSON log line to the debug ingest server (fire-and-forget).
func debugLog(
    location: String,
    message: String,
    data: [String: Any] = [:],
    hypothesisId: String? = nil,
    runId: String? = nil
) {
    _ = location
    _ = message
    _ = data
    _ = hypothesisId
    _ = runId
}
