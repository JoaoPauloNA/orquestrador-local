import Foundation

public enum ServiceEventKind: String, Codable, Sendable {
    case started
    case stopped
    case ready
    case startTimeout
    case stopTimeout
    case activityChecked
    case error
    case stateReconciled
    case stopBlocked
    case stopRequested
}

public struct ServiceEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let serviceId: UUID
    public let kind: ServiceEventKind
    /// Sanitized message — no credentials, no full args, no private paths
    public let message: String
    public let timestamp: Date

    public init(serviceId: UUID, kind: ServiceEventKind, message: String) {
        self.id = UUID()
        self.serviceId = serviceId
        self.kind = kind
        self.message = ServiceEvent.sanitize(message)
        self.timestamp = Date()
    }

    // Strip any environment-style content or suspicious patterns from messages
    public static func sanitize(_ raw: String) -> String {
        var value = String(raw.prefix(512))
        let patterns = [
            #"(?im)^\s*[A-Z][A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|KEY)[A-Z0-9_]*\s*=.*$"#,
            #"(?i)(authorization\s*:\s*)([^\s,;]+)"#,
            #"(?i)((?:token|secret|password|api[_-]?key)\s*[=:]\s*)([^\s,;]+)"#
        ]
        for pattern in patterns {
            value = value.replacingOccurrences(
                of: pattern,
                with: "$1[SUPRIMIDO]",
                options: .regularExpression
            )
        }
        return value
    }
}

/// Ring buffer of events, bounded to maxCount. Thread-safe via actor.
public actor EventLog {
    private var events: [ServiceEvent] = []
    private let maxCount: Int

    public init(maxCount: Int = 50) {
        self.maxCount = maxCount
    }

    public func append(_ event: ServiceEvent) {
        events.append(event)
        if events.count > maxCount {
            events.removeFirst(events.count - maxCount)
        }
    }

    public func recent(limit: Int = 20) -> [ServiceEvent] {
        Array(events.suffix(limit))
    }

    public func all() -> [ServiceEvent] { events }
}
