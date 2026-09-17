import Foundation

/// Checks service readiness via HTTP GET to the registered loopback endpoint.
/// Never follows redirects to external hosts.
public actor ReadinessProbe {

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        // No redirect following to external hosts
        self.session = URLSession(
            configuration: config,
            delegate: NoRedirectDelegate(),
            delegateQueue: nil
        )
    }

    public enum ProbeResult: Sendable {
        case ready(statusCode: Int)
        case notReady(reason: String)
        case timedOut
        case error(String)
    }

    public func check(url: URL, identity: ReadinessIdentity) async -> ProbeResult {
        guard url.host == "127.0.0.1" || url.host == "localhost" || url.host == "::1" else {
            return .error("URL fora do loopback — verificação recusada")
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .notReady(reason: "Resposta não-HTTP")
            }
            // A loopback-only service can use a 401 challenge as a legitimate
            // liveness response: it proves that the expected HTTP server is
            // listening while deliberately keeping its UI/API private.  We
            // still require the registered identity marker in the response;
            // a bare 401 is never considered ready.
            if (200...299).contains(http.statusCode) || http.statusCode == 401 {
                guard matchesIdentity(data: data, identity: identity) else {
                    return .notReady(reason: "Resposta não comprova a identidade cadastrada")
                }
                return .ready(statusCode: http.statusCode)
            }
            return .notReady(reason: "HTTP \(http.statusCode)")
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:           return .timedOut
            case .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet:
                return .notReady(reason: "Serviço não está respondendo")
            default:
                return .error("Erro de rede: \(urlError.localizedDescription)")
            }
        } catch {
            return .error("Erro: \(error.localizedDescription)")
        }
    }

    /// Polls until ready or timeout expires. Returns ready when first 2xx received.
    public func waitUntilReady(
        url: URL,
        identity: ReadinessIdentity,
        timeoutSeconds: Int
    ) async -> ProbeResult {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            let result = await check(url: url, identity: identity)
            switch result {
            case .ready:                return result
            case .notReady, .error:
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            case .timedOut:
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        return .timedOut
    }

    private func matchesIdentity(data: Data, identity: ReadinessIdentity) -> Bool {
        guard data.count <= 2_000_000 else { return false }
        switch identity {
        case .bodyContains(let marker):
            guard let body = String(data: data, encoding: .utf8) else { return false }
            return body.localizedCaseInsensitiveContains(marker)
        case .jsonTopLevelKey(let key):
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else { return false }
            return dictionary[key] != nil
        }
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Refuse all redirects
        completionHandler(nil)
    }
}
