import SwiftUI

public enum ServiceLifecycleState: String, CaseIterable, Identifiable, Sendable, Codable {
    case stopped    = "PARADO"
    case starting   = "INICIANDO"
    case ready      = "PRONTO"
    case stopping   = "PARANDO"
    case error      = "ERRO"
    case external   = "EXTERNO"
    case unknown    = "DESCONHECIDO"

    public var id: String { rawValue }

    // Allowed transitions. Returns true if the transition is valid.
    public func canTransition(to next: ServiceLifecycleState) -> Bool {
        switch (self, next) {
        case (.stopped, .starting):   return true
        case (.starting, .ready):     return true
        case (.starting, .error):     return true
        case (.ready, .stopping):     return true
        case (.ready, .error):        return true
        case (.ready, .unknown):      return true
        case (.stopping, .stopped):   return true
        case (.stopping, .error):     return true
        case (.error, .starting):     return true
        case (.error, .stopped):      return true
        case (.unknown, .ready):      return true
        case (.unknown, .stopped):    return true
        case (.unknown, .error):      return true
        case (_, .external):          return true
        case (_, .unknown):           return true
        case (.unknown, .starting):   return true
        case (.external, .ready):     return true
        case (.external, .stopped):   return true
        default:                      return false
        }
    }

    public var sfSymbol: String {
        switch self {
        case .stopped:  return "circle"
        case .starting: return "progress.indicator"
        case .ready:    return "checkmark.circle.fill"
        case .stopping: return "progress.indicator"
        case .error:    return "xmark.circle.fill"
        case .external: return "arrow.up.right.circle"
        case .unknown:  return "questionmark.circle"
        }
    }

    public var label: String { rawValue }

    // Whether stop action is enabled in this state (UI logic)
    public var stopEnabled: Bool {
        self == .ready
    }

    // Whether start action is enabled
    public var startEnabled: Bool {
        self == .stopped || self == .error
    }

    // Whether open action is enabled
    public var openEnabled: Bool {
        self == .ready
    }
}

public enum ActivityState: Sendable, Codable, Equatable {
    case idle
    case busy(queueRunning: Int, queuePending: Int)
    case unknown
    case notSupported

    public var displayText: String {
        switch self {
        case .idle:                      return "Ocioso"
        case .busy(let r, let p):        return "Ocupado (\(r) em execução, \(p) pendentes)"
        case .unknown:                   return "Atividade não verificada"
        case .notSupported:              return "Verificação de atividade indisponível"
        }
    }

    public var isBusy: Bool {
        if case .busy = self { return true }
        return false
    }

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    public var requiresManualIdleConfirmation: Bool {
        switch self {
        case .unknown, .notSupported: return true
        case .idle, .busy: return false
        }
    }

    public func stopDecision(userConfirmedIdle: Bool) -> StopDecision {
        switch self {
        case .busy: return .blockedBusy
        case .idle: return .allowed
        case .unknown, .notSupported:
            return userConfirmedIdle ? .allowed : .needsManualConfirmation
        }
    }
}

public enum StopDecision: Equatable, Sendable {
    case allowed
    case blockedBusy
    case needsManualConfirmation
}

// Codable support for ActivityState
extension ActivityState {
    private enum CodingKeys: String, CodingKey {
        case type, queueRunning, queuePending
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "idle":         self = .idle
        case "busy":
            let r = try c.decodeIfPresent(Int.self, forKey: .queueRunning) ?? 0
            let p = try c.decodeIfPresent(Int.self, forKey: .queuePending) ?? 0
            self = .busy(queueRunning: r, queuePending: p)
        case "notSupported": self = .notSupported
        default:             self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try c.encode("idle", forKey: .type)
        case .busy(let r, let p):
            try c.encode("busy", forKey: .type)
            try c.encode(r, forKey: .queueRunning)
            try c.encode(p, forKey: .queuePending)
        case .unknown:
            try c.encode("unknown", forKey: .type)
        case .notSupported:
            try c.encode("notSupported", forKey: .type)
        }
    }
}
