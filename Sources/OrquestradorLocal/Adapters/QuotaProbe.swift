import Foundation

/// Reads an optional, unauthenticated quota response from known local AI
/// proxies. This probe never reads credentials, adds authorization headers,
/// persists responses, or exposes server error bodies.
public actor QuotaProbe {
    private static let supportedPorts: Set<Int> = [8310, 8311, 8312, 8320, 8321, 8322]
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration, delegate: QuotaNoRedirectDelegate(), delegateQueue: nil)
    }

    public func check(profile: ServiceProfile) async -> QuotaState {
        guard Self.isSupported(profile) else { return .notChecked }
        let url = profile.readinessURL.deletingLastPathComponent().appendingPathComponent("v1/usage")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  data.count <= 1_000_000 else { return .unavailable }
            return Self.parse(data: data)
        } catch {
            return .unavailable
        }
    }

    static func isSupported(_ profile: ServiceProfile) -> Bool {
        guard let port = profile.readinessURL.port,
              supportedPorts.contains(port),
              profile.readinessURL.host == "127.0.0.1" || profile.readinessURL.host == "localhost" || profile.readinessURL.host == "::1" else {
            return false
        }
        if case .bodyContains(let marker) = profile.readinessIdentity {
            return marker.localizedCaseInsensitiveContains("CLI Proxy API Server")
        }
        return false
    }

    /// Parses only aggregate numeric capacity fields. Unknown schemas are
    /// deliberately reported as unavailable rather than guessed from logs or
    /// token/account fields.
    public nonisolated static func parse(data: Data) -> QuotaState {
        guard data.count <= 1_000_000,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return .unavailable }

        let candidates = [dictionary, dictionary["quota"] as? [String: Any], dictionary["usage"] as? [String: Any], dictionary["data"] as? [String: Any]].compactMap { $0 }
        for candidate in candidates {
            let remaining = number(in: candidate, keys: ["remaining", "available", "remaining_requests"])
            let limit = number(in: candidate, keys: ["limit", "total", "max"])
            let used = number(in: candidate, keys: ["used", "consumed"])
            if let remaining, remaining >= 0 {
                if let limit {
                    if remaining <= limit { return .available(remaining: remaining, limit: limit) }
                } else {
                    return .available(remaining: remaining, limit: nil)
                }
            }
            if let limit, let used, limit >= used, used >= 0 {
                return .available(remaining: limit - used, limit: limit)
            }
        }
        return .unavailable
    }

    private nonisolated static func number(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let number = dictionary[key] as? NSNumber, number.doubleValue.isFinite { return number.doubleValue }
        }
        return nil
    }
}

private final class QuotaNoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
