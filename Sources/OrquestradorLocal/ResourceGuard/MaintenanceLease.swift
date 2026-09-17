import Foundation

/// Estrutura de um Lease (Bloqueio) de Manutenção
public struct MaintenanceLeaseRecord: Identifiable, Sendable, Codable {
    public let id: UUID
    public let owner: String
    public let reason: String
    public let createdAt: Date
    public let expiresAt: Date
    
    public init(
        id: UUID = UUID(),
        owner: String,
        reason: String,
        createdAt: Date = Date(),
        durationSeconds: TimeInterval
    ) {
        self.id = id
        self.owner = owner
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(durationSeconds)
    }
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
}

/// Gerenciador de Leases de Manutenção para adiar restarts/atualizações em jobs ativos
public actor MaintenanceLeaseManager {
    private var activeLeases: [UUID: MaintenanceLeaseRecord] = [:]
    
    public init() {}
    
    public func acquireLease(owner: String, reason: String, durationSeconds: TimeInterval = 300) -> MaintenanceLeaseRecord {
        cleanExpired()
        let lease = MaintenanceLeaseRecord(
            owner: owner,
            reason: reason,
            durationSeconds: durationSeconds
        )
        activeLeases[lease.id] = lease
        return lease
    }
    
    public func renewLease(id: UUID, extendSeconds: TimeInterval = 300) -> MaintenanceLeaseRecord? {
        cleanExpired()
        guard let existing = activeLeases[id] else { return nil }
        let renewed = MaintenanceLeaseRecord(
            id: existing.id,
            owner: existing.owner,
            reason: existing.reason,
            createdAt: existing.createdAt,
            durationSeconds: existing.expiresAt.timeIntervalSince(existing.createdAt) + extendSeconds
        )
        activeLeases[id] = renewed
        return renewed
    }
    
    public func releaseLease(id: UUID) {
        activeLeases.removeValue(forKey: id)
    }
    
    public func isMaintenanceBlocked() -> (blocked: Bool, activeReasons: [String]) {
        cleanExpired()
        if activeLeases.isEmpty {
            return (false, [])
        }
        let reasons = activeLeases.values.map { "\($0.owner): \($0.reason)" }
        return (true, reasons)
    }
    
    public func listActiveLeases() -> [MaintenanceLeaseRecord] {
        cleanExpired()
        return Array(activeLeases.values).sorted(by: { $0.createdAt < $1.createdAt })
    }
    
    private func cleanExpired() {
        let now = Date()
        activeLeases = activeLeases.filter { $0.value.expiresAt > now }
    }
}
