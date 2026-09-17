import Foundation

/// Observed capacity reported by an AI proxy. It intentionally carries no
/// credential, account, or raw response data.
public enum QuotaState: Equatable, Sendable {
    case notChecked
    case unavailable
    case available(remaining: Double, limit: Double?)

    public var displayText: String {
        switch self {
        case .notChecked:
            return "N/D"
        case .unavailable:
            return "Não verificável"
        case .available(let remaining, let limit):
            let remainingText = Self.format(remaining)
            if let limit {
                return "\(remainingText) de \(Self.format(limit)) disponível"
            }
            return "\(remainingText) disponível"
        }
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
