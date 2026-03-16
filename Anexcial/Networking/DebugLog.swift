import Foundation

/// Sends a single NDJSON log line to the debug ingest server (fire-and-forget).
func debugLog(
    location: String,
    message: String,
    data: [String: Any] = [:],
    hypothesisId: String? = nil,
    runId: String? = nil
) {
    var payload: [String: Any] = [
        "sessionId": "aa58fe",
        "location": location,
        "message": message,
        "data": data,
        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ]
    if let h = hypothesisId { payload["hypothesisId"] = h }
    if let r = runId { payload["runId"] = r }
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
    var req = URLRequest(url: URL(string: "http://127.0.0.1:7603/ingest/a3c3d281-576d-4a0b-895a-3d7bacaac2be")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("aa58fe", forHTTPHeaderField: "X-Debug-Session-Id")
    req.httpBody = body
    URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
}
