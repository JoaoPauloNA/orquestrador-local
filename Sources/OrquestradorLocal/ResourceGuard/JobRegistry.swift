import Foundation

/// Tipos de jobs pesados conhecidos pelo ecossistema
public enum HeavyJobKind: String, Codable, Sendable {
    case diffusionGeneration  // e.g. ComfyUI / mflux render
    case audioTranscription   // e.g. LocalTranscriber / Whisper
    case benchmarkRun         // e.g. Matriz de testes automatizada
    case buildTask            // e.g. Compilação de projeto
    case otherHeavyTask
}

/// Registro imutável de um job pesado em andamento
public struct ActiveJob: Identifiable, Sendable, Codable {
    public let id: UUID
    public let serviceLabel: String
    public let kind: HeavyJobKind
    public let description: String
    public let startedAt: Date
    public let estimatedDurationSeconds: TimeInterval?
    
    public init(
        id: UUID = UUID(),
        serviceLabel: String,
        kind: HeavyJobKind,
        description: String,
        startedAt: Date = Date(),
        estimatedDurationSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.serviceLabel = serviceLabel
        self.kind = kind
        self.description = description
        self.startedAt = startedAt
        self.estimatedDurationSeconds = estimatedDurationSeconds
    }
}

/// Registro de Jobs: gerencia e rastreia os trabalhos pesados ativos em memória
public actor JobRegistry {
    private var activeJobs: [UUID: ActiveJob] = [:]
    
    public init() {}
    
    public func registerJob(serviceLabel: String, kind: HeavyJobKind, description: String, estimatedDuration: TimeInterval? = nil) -> ActiveJob {
        let job = ActiveJob(
            serviceLabel: serviceLabel,
            kind: kind,
            description: description,
            startedAt: Date(),
            estimatedDurationSeconds: estimatedDuration
        )
        activeJobs[job.id] = job
        return job
    }
    
    public func unregisterJob(id: UUID) {
        activeJobs.removeValue(forKey: id)
    }
    
    public func listActiveJobs() -> [ActiveJob] {
        return Array(activeJobs.values).sorted(by: { $0.startedAt < $1.startedAt })
    }
    
    public func hasActiveJobs(for serviceLabel: String? = nil) -> Bool {
        if let serviceLabel {
            return activeJobs.values.contains(where: { $0.serviceLabel == serviceLabel })
        }
        return !activeJobs.isEmpty
    }
    
    public func activeJobCount() -> Int {
        return activeJobs.count
    }
}
