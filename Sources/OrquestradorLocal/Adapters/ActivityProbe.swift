import Foundation

/// Checks service activity via HTTP GET to a loopback queue/activity endpoint.
/// Returns counts only — never logs full response bodies.
/// A missing endpoint or non-200 response → .unknown (not .idle).
public actor ActivityProbe {

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        self.session = URLSession(configuration: config)
    }

    /// Check activity at the given URL.
    /// - Parameter runningKey: JSON key for running count (default: "queue_running")
    /// - Parameter pendingKey: JSON key for pending count (default: "queue_pending")
    public func check(
        url: URL,
        runningKey: String = "queue_running",
        pendingKey: String = "queue_pending"
    ) async -> ActivityState {
        guard url.host == "127.0.0.1" || url.host == "localhost" || url.host == "::1" else {
            return .unknown
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .unknown
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .unknown
            }
            guard let running = count(json[runningKey]),
                  let pending = count(json[pendingKey]) else {
                return .unknown
            }
            if running == 0 && pending == 0 {
                return .idle
            }
            return .busy(queueRunning: running, queuePending: pending)
        } catch {
            // Connection refused, timeout, etc. — all mean we cannot determine activity
            return .unknown
        }
    }

    private func count(_ value: Any?) -> Int? {
        if let integer = value as? Int { return integer >= 0 ? integer : nil }
        if let array = value as? [Any] { return array.count }
        return nil
    }

    /// Returns .notSupported for profiles with no activityURL.
    public func checkIfSupported(profile: ServiceProfile) async -> ActivityState {
        guard let url = profile.activityURL else { return .notSupported }
        return await check(
            url: url,
            runningKey: profile.activityRunningKey ?? "queue_running",
            pendingKey: profile.activityPendingKey ?? "queue_pending"
        )
    }
}
