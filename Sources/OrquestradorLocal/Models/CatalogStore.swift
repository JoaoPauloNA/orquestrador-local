import Foundation

/// Persisted catalog with atomic writes and versioned schema.
/// Corrupt or missing catalog falls back to last valid version, never executes partial data.
public actor CatalogStore {
    public static let schemaVersion = 1

    private let fileURL: URL
    private let backupURL: URL
    private var profiles: [ServiceProfile] = []

    public init() {
        // This is deliberately an explicit, task-scoped override rather than a
        // different production location.  It lets packaged-app smoke tests use
        // a synthetic catalog without reading or writing a person's catalog.
        if let override = ProcessInfo.processInfo.environment["ORQ_CATALOG_PATH"],
           override.hasPrefix("/") {
            let url = URL(fileURLWithPath: override)
            fileURL = url
            backupURL = url.deletingPathExtension().appendingPathExtension("last-valid.json")
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("OrquestradorLocal", isDirectory: true)
        fileURL = dir.appendingPathComponent("catalog-v1.json")
        backupURL = dir.appendingPathComponent("catalog-v1.last-valid.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        self.backupURL = fileURL.deletingPathExtension().appendingPathExtension("last-valid.json")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            profiles = try decode(fileURL).profiles
        } catch {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { throw error }
            profiles = try decode(backupURL).profiles
            throw CatalogError.recoveredFromBackup
        }
    }

    public func save() throws {
        let envelope = CatalogEnvelope(schemaVersion: Self.schemaVersion, profiles: profiles)
        let data = try JSONEncoder().encode(envelope)
        // Write the recoverable copy *before* replacing the primary.  This covers
        // the first save too, and means an interrupted primary replacement still
        // leaves the newest fully encoded catalog available for recovery.
        try durableAtomicWrite(data, to: backupURL)
        try durableAtomicWrite(data, to: fileURL)
    }

    public func allProfiles() -> [ServiceProfile] { profiles }

    public func profile(id: UUID) -> ServiceProfile? {
        profiles.first { $0.id == id }
    }

    public func add(_ profile: ServiceProfile) throws {
        guard !profiles.contains(where: { $0.label == profile.label }) else {
            throw CatalogError.duplicateLabel(profile.label)
        }
        let previous = profiles
        profiles.append(profile)
        do { try save() } catch { profiles = previous; throw error }
    }

    public func replace(id: UUID, with profile: ServiceProfile) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw CatalogError.notFound(id)
        }
        let replacement = profile.replacingID(id)
        if profiles.enumerated().contains(where: { offset, existing in
            offset != index && existing.label == replacement.label
        }) {
            throw CatalogError.duplicateLabel(replacement.label)
        }
        let previous = profiles
        profiles[index] = replacement
        do { try save() } catch { profiles = previous; throw error }
    }

    public func remove(id: UUID) throws {
        guard profiles.contains(where: { $0.id == id }) else {
            throw CatalogError.notFound(id)
        }
        let previous = profiles
        profiles.removeAll { $0.id == id }
        do { try save() } catch { profiles = previous; throw error }
    }

    private func decode(_ url: URL) throws -> CatalogEnvelope {
        let decoded = try JSONDecoder().decode(CatalogEnvelope.self, from: Data(contentsOf: url))
        guard decoded.schemaVersion == Self.schemaVersion else {
            throw CatalogError.schemaMismatch(decoded.schemaVersion, Self.schemaVersion)
        }
        return decoded
    }

    private func durableAtomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
}

public enum CatalogError: Error, LocalizedError {
    case schemaMismatch(Int, Int)
    case duplicateLabel(String)
    case notFound(UUID)
    case writeInterrupted
    case recoveredFromBackup

    public var errorDescription: String? {
        switch self {
        case .schemaMismatch(let got, let want):
            return "Esquema do catálogo incompatível: encontrado v\(got), esperado v\(want)"
        case .duplicateLabel(let l):
            return "Label já cadastrada: \(l)"
        case .notFound(let id):
            return "Perfil não encontrado: \(id)"
        case .writeInterrupted:
            return "Gravação interrompida — versão anterior preservada"
        case .recoveredFromBackup:
            return "Catálogo atual inválido — última versão válida foi recuperada"
        }
    }
}

private struct CatalogEnvelope: Codable {
    let schemaVersion: Int
    let profiles: [ServiceProfile]
}
