import Foundation

/// Estado de Saúde do Armazenamento de Leases de Manutenção
public enum LeaseStoreHealth: String, Codable, Sendable {
    case healthy     // Arquivo existe e decodificou perfeitamente
    case missing     // Arquivo ainda não existe (estado normal inicial)
    case corrupted   // Arquivo existe mas contém JSON inválido/corrompido
    case unavailable // Falha de I/O ou sem permissão de acesso ao diretório
}

/// Estrutura de um Lease (Bloqueio) de Manutenção
public struct MaintenanceLeaseRecord: Identifiable, Sendable, Codable, Equatable {
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
    
    public init(
        id: UUID,
        owner: String,
        reason: String,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.owner = owner
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
}

/// Gerenciador de Leases de Manutenção com Persistência Atômica em Disco e Monitor de Saúde
public actor MaintenanceLeaseManager {
    private var activeLeases: [UUID: MaintenanceLeaseRecord] = [:]
    private let storageURL: URL?
    public private(set) var storeHealth: LeaseStoreHealth
    
    public init(storageURL: URL? = nil) {
        let resolvedURL: URL?
        if let storageURL {
            resolvedURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let dir = appSupport?.appendingPathComponent("OrquestradorLocal", isDirectory: true)
            if let dir {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                resolvedURL = dir.appendingPathComponent("maintenance_leases.json")
            } else {
                resolvedURL = nil
            }
        }
        self.storageURL = resolvedURL
        let (leases, health) = Self.loadLeases(from: resolvedURL)
        self.activeLeases = leases
        self.storeHealth = health
    }
    
    public func acquireLease(owner: String, reason: String, durationSeconds: TimeInterval = 300) -> MaintenanceLeaseRecord {
        cleanExpired()
        let lease = MaintenanceLeaseRecord(
            owner: owner,
            reason: reason,
            durationSeconds: durationSeconds
        )
        activeLeases[lease.id] = lease
        saveToDisk()
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
            expiresAt: existing.expiresAt.addingTimeInterval(extendSeconds)
        )
        activeLeases[id] = renewed
        saveToDisk()
        return renewed
    }
    
    public func releaseLease(id: UUID) {
        activeLeases.removeValue(forKey: id)
        saveToDisk()
    }
    
    public func isMaintenanceBlocked() -> (blocked: Bool, activeReasons: [String]) {
        cleanExpired()
        if storeHealth == .corrupted || storeHealth == .unavailable {
            return (true, ["Armazenamento de Leases corrompido/indisponível (bloqueio conservador de segurança)"])
        }
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
        let beforeCount = activeLeases.count
        activeLeases = activeLeases.filter { $0.value.expiresAt > now }
        if activeLeases.count != beforeCount {
            saveToDisk()
        }
    }
    
    private static func loadLeases(from url: URL?) -> ([UUID: MaintenanceLeaseRecord], LeaseStoreHealth) {
        guard let url else {
            return ([:], .unavailable)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ([:], .missing)
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([MaintenanceLeaseRecord].self, from: data)
            let now = Date()
            var loaded: [UUID: MaintenanceLeaseRecord] = [:]
            for lease in decoded {
                if lease.expiresAt > now {
                    loaded[lease.id] = lease
                }
            }
            return (loaded, .healthy)
        } catch {
            // Em caso de corrupção ou erro de decoding, adota estado seguro sem crash e reporta .corrupted
            return ([:], .corrupted)
        }
    }
    
    private func saveToDisk() {
        guard let storageURL else {
            storeHealth = .unavailable
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let list = Array(activeLeases.values)
            let data = try encoder.encode(list)
            try data.write(to: storageURL, options: .atomic)
            storeHealth = .healthy
        } catch {
            storeHealth = .unavailable
        }
    }
}
