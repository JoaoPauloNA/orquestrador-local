import XCTest
@testable import OrquestradorLocal

final class ResourceGuardTests: XCTestCase {
    
    // Mock Provider de Métricas
    struct MockMetricsProvider: SystemMetricsProvider {
        var totalRAM: UInt64 = 16 * 1024 * 1024 * 1024
        var freeRAM: UInt64 = 4 * 1024 * 1024 * 1024
        var usedRAM: UInt64 = 12 * 1024 * 1024 * 1024
        var pressure: MemoryPressureLevel = .normal
        var totalSwap: UInt64 = 8 * 1024 * 1024 * 1024
        var usedSwap: UInt64 = 2 * 1024 * 1024 * 1024
        var freeSwap: UInt64 = 6 * 1024 * 1024 * 1024
        var cpuPercent: Double? = 15.0
        var thermal: ThermalLevel = .nominal
        var throttled: Bool = false
        
        func collectMetrics() async -> (
            totalRAM: UInt64,
            freeRAM: UInt64,
            usedRAM: UInt64,
            pressure: MemoryPressureLevel,
            totalSwap: UInt64,
            usedSwap: UInt64,
            freeSwap: UInt64,
            cpuPercent: Double?,
            thermal: ThermalLevel,
            throttled: Bool
        ) {
            return (totalRAM, freeRAM, usedRAM, pressure, totalSwap, usedSwap, freeSwap, cpuPercent, thermal, throttled)
        }
    }
    
    func testResourceMonitorSampling() async {
        let mock = MockMetricsProvider()
        let monitor = ResourceMonitor(provider: mock)
        
        let snapshot = await monitor.sample()
        XCTAssertEqual(snapshot.totalRAMBytes, 16 * 1024 * 1024 * 1024)
        XCTAssertEqual(snapshot.memoryPressure, .normal)
        XCTAssertEqual(snapshot.swapDeltaBytes, 0)
    }
    
    func testAdmissionPolicyAdmitNormal() {
        let policy = AdmissionPolicy()
        let snap = SystemResourceSnapshot(
            totalRAMBytes: 16 * 1024 * 1024 * 1024,
            freeRAMBytes: 4 * 1024 * 1024 * 1024,
            usedRAMBytes: 12 * 1024 * 1024 * 1024,
            memoryPressure: .normal,
            totalSwapBytes: 8 * 1024 * 1024 * 1024,
            usedSwapBytes: 2 * 1024 * 1024 * 1024,
            freeSwapBytes: 6 * 1024 * 1024 * 1024,
            swapDeltaBytes: 0,
            cpuUsagePercent: 10.0,
            thermalLevel: .nominal,
            isThrottled: false
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        XCTAssertEqual(decision, .admit(reason: "Recursos adequados para admissão da carga."))
    }
    
    func testAdmissionPolicyQueueOnCriticalPressure() {
        let policy = AdmissionPolicy()
        let snap = SystemResourceSnapshot(
            totalRAMBytes: 16 * 1024 * 1024 * 1024,
            freeRAMBytes: 1 * 1024 * 1024 * 1024,
            usedRAMBytes: 15 * 1024 * 1024 * 1024,
            memoryPressure: .critical,
            totalSwapBytes: 8 * 1024 * 1024 * 1024,
            usedSwapBytes: 6 * 1024 * 1024 * 1024,
            freeSwapBytes: 2 * 1024 * 1024 * 1024,
            swapDeltaBytes: 0,
            cpuUsagePercent: 85.0,
            thermalLevel: .nominal,
            isThrottled: false
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        XCTAssertEqual(decision, .queue(reason: "Pressão de memória em estado CRÍTICO. Carga enfileirada para prevenir OOM."))
    }
    
    func testAdmissionPolicyQueueOnHeavyJobLimit() {
        let config = AdmissionConfig(maxConcurrentHeavyJobs: 2)
        let policy = AdmissionPolicy(config: config)
        let snap = SystemResourceSnapshot(
            totalRAMBytes: 16 * 1024 * 1024 * 1024,
            freeRAMBytes: 8 * 1024 * 1024 * 1024,
            usedRAMBytes: 8 * 1024 * 1024 * 1024,
            memoryPressure: .normal,
            totalSwapBytes: 8 * 1024 * 1024 * 1024,
            usedSwapBytes: 2 * 1024 * 1024 * 1024,
            freeSwapBytes: 6 * 1024 * 1024 * 1024,
            swapDeltaBytes: 0,
            cpuUsagePercent: 10.0,
            thermalLevel: .nominal,
            isThrottled: false
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 2)
        XCTAssertEqual(decision, .queue(reason: "Limite de jobs pesados concorrentes atingido (2/2)."))
    }
    
    func testMaintenanceLeaseBlocking() async {
        let leaseManager = MaintenanceLeaseManager()
        let lease = await leaseManager.acquireLease(owner: "ComfyUI", reason: "Renderização 4K em lote", durationSeconds: 60)
        
        let (blocked, reasons) = await leaseManager.isMaintenanceBlocked()
        XCTAssertTrue(blocked)
        XCTAssertEqual(reasons.count, 1)
        XCTAssertTrue(reasons[0].contains("Renderização 4K"))
        
        await leaseManager.releaseLease(id: lease.id)
        let (blockedAfter, _) = await leaseManager.isMaintenanceBlocked()
        XCTAssertFalse(blockedAfter)
    }
    
    func testMaintenanceLeaseExpiration() async {
        let leaseManager = MaintenanceLeaseManager()
        _ = await leaseManager.acquireLease(owner: "Test", reason: "Quick Test", durationSeconds: -1) // já expirado
        
        let (blocked, _) = await leaseManager.isMaintenanceBlocked()
        XCTAssertFalse(blocked)
    }
    
    func testNonInterferenceExternalProcess() async {
        let coordinator = await ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: MockMetricsProvider()),
            jobRegistry: JobRegistry(),
            leaseManager: MaintenanceLeaseManager(),
            policy: AdmissionPolicy()
        )
        
        // Avaliação de serviço não deve disparar comandos no launchctl ou processos do SO
        let decision = await coordinator.evaluateAdmission(for: "com.joaopaulo.specialist-gateway")
        XCTAssertEqual(decision, .admit(reason: "Recursos adequados para admissão da carga."))
    }
}
