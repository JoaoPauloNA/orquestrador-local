import Foundation
import SwiftUI

/// Modo de operação do Resource Guard
public enum ResourceGuardMode: String, Codable, Sendable {
    case observing       // Apenas monitora e exibe métricas (sem bloquear)
    case activeAdmission // Avalia admissão e recomenda filas/bloqueios preventivos
}

/// Fachada Principal do Resource Guard no Orquestrador
@MainActor
public final class ResourceGuardCoordinator: ObservableObject {
    @Published public private(set) var currentSnapshot: SystemResourceSnapshot?
    @Published public private(set) var mode: ResourceGuardMode = .observing
    @Published public private(set) var activeJobs: [ActiveJob] = []
    @Published public private(set) var activeLeases: [MaintenanceLeaseRecord] = []
    @Published public private(set) var lastDecision: String = "Monitoramento ativo"
    
    private let monitor: ResourceMonitor
    private let jobRegistry: JobRegistry
    private let leaseManager: MaintenanceLeaseManager
    private let policy: AdmissionPolicy
    
    private var pollingTask: Task<Void, Never>?
    
    public init(
        monitor: ResourceMonitor = ResourceMonitor(),
        jobRegistry: JobRegistry = JobRegistry(),
        leaseManager: MaintenanceLeaseManager = MaintenanceLeaseManager(),
        policy: AdmissionPolicy = AdmissionPolicy()
    ) {
        self.monitor = monitor
        self.jobRegistry = jobRegistry
        self.leaseManager = leaseManager
        self.policy = policy
        
        startMonitoring()
    }
    
    public func setMode(_ mode: ResourceGuardMode) {
        self.mode = mode
    }
    
    public func startMonitoring(intervalSeconds: UInt64 = 5) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let snap = await self.monitor.sample()
                let jobs = await self.jobRegistry.listActiveJobs()
                let leases = await self.leaseManager.listActiveLeases()
                
                self.currentSnapshot = snap
                self.activeJobs = jobs
                self.activeLeases = leases
                
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            }
        }
    }
    
    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    public func evaluateAdmission(for serviceLabel: String, isMaintenance: Bool = false) async -> AdmissionDecision {
        let snap = await monitor.sample()
        let jobCount = await jobRegistry.activeJobCount()
        let (blocked, _) = await leaseManager.isMaintenanceBlocked()
        
        let decision = policy.evaluate(
            snapshot: snap,
            activeJobCount: jobCount,
            isMaintenanceTask: isMaintenance,
            hasMaintenanceLease: blocked
        )
        
        switch decision {
        case .admit(let reason):
            self.lastDecision = "ADMIT: \(reason)"
        case .queue(let reason):
            self.lastDecision = "QUEUE: \(reason)"
        case .deferMaintenance(let reason):
            self.lastDecision = "DEFER: \(reason)"
        case .unknown(let reason):
            self.lastDecision = "UNKNOWN: \(reason)"
        }
        
        return decision
    }
    
    public func registerHeavyJob(serviceLabel: String, kind: HeavyJobKind, description: String) async -> ActiveJob {
        let job = await jobRegistry.registerJob(serviceLabel: serviceLabel, kind: kind, description: description)
        self.activeJobs = await jobRegistry.listActiveJobs()
        return job
    }
    
    public func unregisterHeavyJob(id: UUID) async {
        await jobRegistry.unregisterJob(id: id)
        self.activeJobs = await jobRegistry.listActiveJobs()
    }
    
    public func acquireMaintenanceLease(owner: String, reason: String, duration: TimeInterval = 300) async -> MaintenanceLeaseRecord {
        let lease = await leaseManager.acquireLease(owner: owner, reason: reason, durationSeconds: duration)
        self.activeLeases = await leaseManager.listActiveLeases()
        return lease
    }
    
    public func releaseMaintenanceLease(id: UUID) async {
        await leaseManager.releaseLease(id: id)
        self.activeLeases = await leaseManager.listActiveLeases()
    }
}
