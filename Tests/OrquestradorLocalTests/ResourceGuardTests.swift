import XCTest
@testable import OrquestradorLocal

@MainActor
final class ResourceGuardTests: XCTestCase {
    
    // Mock Provider de Métricas
    struct MockMetricsProvider: SystemMetricsProvider {
        var totalRAM: UInt64? = 16 * 1024 * 1024 * 1024
        var freeRAM: UInt64? = 4 * 1024 * 1024 * 1024
        var usedRAM: UInt64? = 12 * 1024 * 1024 * 1024
        var pressure: MemoryPressureLevel = .normal
        var totalSwap: UInt64? = 8 * 1024 * 1024 * 1024
        var usedSwap: UInt64? = 2 * 1024 * 1024 * 1024
        var freeSwap: UInt64? = 6 * 1024 * 1024 * 1024
        var cpuPercent: Double? = 15.0
        var thermal: ThermalLevel = .nominal
        var throttled: Bool? = false
        
        func collectMetrics() async -> (
            totalRAM: UInt64?,
            freeRAM: UInt64?,
            usedRAM: UInt64?,
            pressure: MemoryPressureLevel,
            totalSwap: UInt64?,
            usedSwap: UInt64?,
            freeSwap: UInt64?,
            cpuPercent: Double?,
            thermal: ThermalLevel,
            throttled: Bool?
        ) {
            return (totalRAM, freeRAM, usedRAM, pressure, totalSwap, usedSwap, freeSwap, cpuPercent, thermal, throttled)
        }
    }
    
    // MARK: - 01. Observer Does Not Block
    func testObserverDoesNotBlock() async {
        let mock = MockMetricsProvider(pressure: .critical)
        let coordinator = await ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: mock),
            initialMode: .observing
        )
        
        let decision = await coordinator.evaluateAdmission(for: "com.joaopaulo.secondmind")
        // No modo observador, a policy retorna a decisão técnica, mas o OrchestrationCoordinator não barra o start
        if case .queue = decision {
            XCTAssertTrue(true)
        } else {
            XCTFail("Esperado queue devido a critical pressure, mas avaliado como \(decision)")
        }
        XCTAssertEqual(coordinator.mode, .observing)
    }
    
    // MARK: - 02. Active Admission Blocks Critical Memory
    func testActiveAdmissionBlocksCriticalMemory() async {
        let mock = MockMetricsProvider(pressure: .critical)
        let coordinator = await ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: mock),
            initialMode: .activeAdmission
        )
        
        let decision = await coordinator.evaluateAdmission(for: "com.joaopaulo.test")
        XCTAssertEqual(decision, .queue(reason: "Pressão de memória estimada em estado CRÍTICO. Carga enfileirada para prevenir OOM."))
    }
    
    // MARK: - 03. Active Admission Blocks Excessive Swap Growth
    func testActiveAdmissionBlocksExcessiveSwapGrowth() async {
        let policy = AdmissionPolicy(config: AdmissionConfig(maxSwapGrowthBytes: 1 * 1024 * 1024 * 1024))
        let snap = SystemResourceSnapshot(
            totalRAMBytes: 16 * 1024 * 1024 * 1024,
            freeRAMBytes: 4 * 1024 * 1024 * 1024,
            usedRAMBytes: 12 * 1024 * 1024 * 1024,
            memoryPressure: .normal,
            totalSwapBytes: 8 * 1024 * 1024 * 1024,
            usedSwapBytes: 4 * 1024 * 1024 * 1024,
            freeSwapBytes: 4 * 1024 * 1024 * 1024,
            swapDeltaBytes: 2 * 1024 * 1024 * 1024, // 2 GB > 1 GB limit
            cpuUsagePercent: 10.0,
            thermalLevel: .nominal,
            isThrottled: false
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        if case .queue(let reason) = decision {
            XCTAssertTrue(reason.contains("Crescimento de swap excessivo"))
        } else {
            XCTFail("Deveria ter enfileirado por swap delta excessivo")
        }
    }
    
    // MARK: - 04. Active Admission Blocks Heavy-Job Concurrency
    func testActiveAdmissionBlocksHeavyJobConcurrency() async {
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
    
    // MARK: - 05. Unknown Metrics Block Automatic Active Admission
    func testUnknownMetricsBlockAutomaticActiveAdmission() async {
        let policy = AdmissionPolicy()
        let snap = SystemResourceSnapshot(
            totalRAMBytes: nil,
            freeRAMBytes: nil,
            usedRAMBytes: nil,
            memoryPressure: .unknown,
            totalSwapBytes: nil,
            usedSwapBytes: nil,
            freeSwapBytes: nil,
            swapDeltaBytes: nil,
            cpuUsagePercent: nil,
            thermalLevel: .unknown,
            isThrottled: nil
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        if case .unknown(let reason) = decision {
            XCTAssertTrue(reason.contains("indisponíveis"))
        } else {
            XCTFail("Esperado UNKNOWN quando métricas são nulas, recebido: \(decision)")
        }
    }
    
    // MARK: - 06. Normal Resources Admit
    func testNormalResourcesAdmit() {
        let policy = AdmissionPolicy()
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
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        XCTAssertEqual(decision, .admit(reason: "Recursos adequados para admissão da carga."))
    }
    
    // MARK: - 07. Lease Persists After Manager Recreation
    func testLeasePersistsAfterManagerRecreation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storageURL = tempDir.appendingPathComponent("test_leases.json")
        
        let manager1 = MaintenanceLeaseManager(storageURL: storageURL)
        let lease = await manager1.acquireLease(owner: "ComfyUI", reason: "Batch Render", durationSeconds: 600)
        
        // Recria manager apontando para o mesmo arquivo em disco
        let manager2 = MaintenanceLeaseManager(storageURL: storageURL)
        let leases = await manager2.listActiveLeases()
        
        XCTAssertEqual(leases.count, 1)
        XCTAssertEqual(leases.first?.id, lease.id)
        XCTAssertEqual(leases.first?.owner, "ComfyUI")
        XCTAssertEqual(leases.first?.reason, "Batch Render")
    }
    
    // MARK: - 08. Expired Lease Not Restored
    func testExpiredLeaseNotRestored() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storageURL = tempDir.appendingPathComponent("test_leases_exp.json")
        let manager1 = MaintenanceLeaseManager(storageURL: storageURL)
        _ = await manager1.acquireLease(owner: "TempTask", reason: "Quick", durationSeconds: -10)
        
        let manager2 = MaintenanceLeaseManager(storageURL: storageURL)
        let (blocked, _) = await manager2.isMaintenanceBlocked()
        XCTAssertFalse(blocked)
        let list = await manager2.listActiveLeases()
        XCTAssertTrue(list.isEmpty)
    }
    
    // MARK: - 09. Corrupt Lease Store Handled Safely
    func testCorruptLeaseStoreHandledSafely() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storageURL = tempDir.appendingPathComponent("corrupt_leases.json")
        try "GARBAGE_JSON_DATA{{{".write(to: storageURL, atomically: true, encoding: .utf8)
        
        let manager = MaintenanceLeaseManager(storageURL: storageURL)
        let (blocked, _) = await manager.isMaintenanceBlocked()
        XCTAssertFalse(blocked)
        let list = await manager.listActiveLeases()
        XCTAssertTrue(list.isEmpty)
    }
    
    // MARK: - 10. Thermal Unknown Handled Correctly
    func testThermalUnknownHandledCorrectly() {
        let policy = AdmissionPolicy()
        let snap = SystemResourceSnapshot(
            totalRAMBytes: 16 * 1024 * 1024 * 1024,
            freeRAMBytes: 8 * 1024 * 1024 * 1024,
            usedRAMBytes: 8 * 1024 * 1024 * 1024,
            memoryPressure: .normal,
            totalSwapBytes: 8 * 1024 * 1024 * 1024,
            usedSwapBytes: 2 * 1024 * 1024 * 1024,
            freeSwapBytes: 6 * 1024 * 1024 * 1024,
            swapDeltaBytes: 0,
            cpuUsagePercent: nil,
            thermalLevel: .unknown,
            isThrottled: nil
        )
        
        let decision = policy.evaluate(snapshot: snap, activeJobCount: 0)
        // Quando thermal é unknown mas RAM/Swap estão OK, admite normalmente sem bloquear falsamente
        XCTAssertEqual(decision, .admit(reason: "Recursos adequados para admissão da carga."))
    }
    
    // MARK: - 11. Memory Metric Failure Returns N/D or Indisponível
    func testMemoryMetricFailureFormatting() {
        let snap = SystemResourceSnapshot(
            totalRAMBytes: nil,
            freeRAMBytes: nil,
            usedRAMBytes: nil,
            memoryPressure: .unknown,
            totalSwapBytes: nil,
            usedSwapBytes: nil,
            freeSwapBytes: nil,
            swapDeltaBytes: nil,
            cpuUsagePercent: nil,
            thermalLevel: .unknown,
            isThrottled: nil
        )
        
        XCTAssertEqual(snap.formattedRAMUsed, "Indisponível")
        XCTAssertEqual(snap.formattedSwapUsed, "Indisponível")
        XCTAssertEqual(snap.formattedSwapDelta, "N/D")
    }
    
    // MARK: - 12. Non Interference Test
    func testNonInterferenceExternalProcess() async {
        let coordinator = await ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: MockMetricsProvider()),
            jobRegistry: JobRegistry(),
            leaseManager: MaintenanceLeaseManager(),
            policy: AdmissionPolicy(),
            initialMode: .observing
        )
        
        let decision = await coordinator.evaluateAdmission(for: "com.joaopaulo.specialist-gateway")
        XCTAssertEqual(decision, .admit(reason: "Recursos adequados para admissão da carga."))
    }
}
