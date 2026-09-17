import XCTest
import Darwin
@testable import OrquestradorLocal

@MainActor
final class ResourceGuardLifecycleIntegrationTests: XCTestCase {
    private var label = ""
    private var plistURL: URL!
    private var workURL: URL!
    private var catalogURL: URL!
    private var port = 0
    private var ownsPlist = false
    private var ownsPossibleJob = false

    override func setUpWithError() throws {
        do {
            let token = UUID().uuidString.lowercased()
            label = "local.orquestrador.rglifecycle.\(token)"
            plistURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
            XCTAssertFalse(FileManager.default.fileExists(atPath: plistURL.path), "Refusing to overwrite foreign LaunchAgent")
            let fixtureRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/OrquestradorLocalFixtures", isDirectory: true)
            try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
            workURL = fixtureRoot.appendingPathComponent(token, isDirectory: true)
            XCTAssertFalse(FileManager.default.fileExists(atPath: workURL.path), "Refusing to reuse a foreign fixture directory")
            try FileManager.default.createDirectory(at: workURL, withIntermediateDirectories: false)
            catalogURL = workURL.appendingPathComponent("catalog.json")
            port = try reserveLoopbackPort()
            let fixture = workURL.appendingPathComponent("loopback_service.py")
            try FileManager.default.copyItem(at: URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures/loopback_service.py"), to: fixture)
            try Data("idle\n".utf8).write(to: workURL.appendingPathComponent("activity.txt"), options: .atomic)
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": ["/usr/bin/python3", fixture.path, "--port", "\(port)", "--activity-file", workURL.appendingPathComponent("activity.txt").path],
                "WorkingDirectory": workURL.path, "RunAtLoad": false,
                "StandardOutPath": workURL.appendingPathComponent("out.log").path,
                "StandardErrorPath": workURL.appendingPathComponent("err.log").path
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            ownsPlist = true
        } catch {
            cleanupOwnedArtifacts()
            throw error
        }
    }

    override func tearDownWithError() throws {
        cleanupOwnedArtifacts()
    }

    private func cleanupOwnedArtifacts() {
        if ownsPossibleJob {
            let adapter = LaunchAgentAdapter()
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                _ = await adapter.bootout(label: label, domain: .gui)
                semaphore.signal()
            }
            semaphore.wait()
            ownsPossibleJob = false
        }
        if ownsPlist, let plistURL {
            try? FileManager.default.removeItem(at: plistURL)
            ownsPlist = false
        }
        if let workURL {
            try? FileManager.default.removeItem(at: workURL)
        }
    }

    private func reserveLoopbackPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(0).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard nameResult == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    // Mock Provider de Métricas configurável para testes
    struct ConfigurableMetricsProvider: SystemMetricsProvider {
        var totalRAM: UInt64?
        var freeRAM: UInt64?
        var usedRAM: UInt64?
        var pressure: MemoryPressureLevel
        var totalSwap: UInt64?
        var usedSwap: UInt64?
        var freeSwap: UInt64?
        var cpuPercent: Double?
        var thermal: ThermalLevel
        var throttled: Bool?
        
        init(
            totalRAM: UInt64? = 16 * 1024 * 1024 * 1024,
            freeRAM: UInt64? = 8 * 1024 * 1024 * 1024,
            usedRAM: UInt64? = 8 * 1024 * 1024 * 1024,
            pressure: MemoryPressureLevel = .normal,
            totalSwap: UInt64? = 8 * 1024 * 1024 * 1024,
            usedSwap: UInt64? = 2 * 1024 * 1024 * 1024,
            freeSwap: UInt64? = 6 * 1024 * 1024 * 1024,
            cpuPercent: Double? = nil,
            thermal: ThermalLevel = .nominal,
            throttled: Bool? = false
        ) {
            self.totalRAM = totalRAM
            self.freeRAM = freeRAM
            self.usedRAM = usedRAM
            self.pressure = pressure
            self.totalSwap = totalSwap
            self.usedSwap = usedSwap
            self.freeSwap = freeSwap
            self.cpuPercent = cpuPercent
            self.thermal = thermal
            self.throttled = throttled
        }
        
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
    
    // 01. Observing Mode Does Not Block Start Even on Critical Pressure
    func testObservingModeAllowsStartUnderCriticalPressure() async throws {
        let metrics = ConfigurableMetricsProvider(pressure: .critical)
        let rg = ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: metrics),
            initialMode: .observing
        )
        
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(
            catalog: try CatalogStore(fileURL: catalogURL),
            launchAgent: adapter,
            resourceGuard: rg
        )
        
        let input = ProfileValidator.RawInput(
            name: "Fixture",
            label: label,
            plistPath: plistURL.path,
            executablePath: "/usr/bin/python3",
            workingDirectory: workURL.path,
            readinessURLString: "http://127.0.0.1:\(port)/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "orquestrador-fixture",
            activityURLString: "http://127.0.0.1:\(port)/queue",
            openURLString: "http://127.0.0.1:\(port)/",
            readinessTimeoutSeconds: 5,
            stopTimeoutSeconds: 5
        )
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        
        ownsPossibleJob = true
        // Solicita início
        await coordinator.startService(id)
        
        let runtime = try XCTUnwrap(coordinator.services.first)
        
        // Em modo observador, o serviço DEVE ter iniciado e alcançado .ready
        XCTAssertEqual(runtime.lifecycleState, .ready)
        
        // Finaliza graciosamente para limpeza
        await coordinator.stopService(id, userConfirmedIdle: true)
        ownsPossibleJob = false
    }
    
    // 02. Active Admission Blocks Start on Critical Memory Pressure
    func testActiveAdmissionBlocksStartUnderCriticalPressure() async throws {
        let metrics = ConfigurableMetricsProvider(pressure: .critical)
        let rg = ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: metrics),
            initialMode: .activeAdmission
        )
        
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(
            catalog: try CatalogStore(fileURL: catalogURL),
            launchAgent: adapter,
            resourceGuard: rg
        )
        
        let input = ProfileValidator.RawInput(
            name: "Fixture",
            label: label,
            plistPath: plistURL.path,
            executablePath: "/usr/bin/python3",
            workingDirectory: workURL.path,
            readinessURLString: "http://127.0.0.1:\(port)/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "orquestrador-fixture",
            activityURLString: "http://127.0.0.1:\(port)/queue",
            openURLString: "http://127.0.0.1:\(port)/",
            readinessTimeoutSeconds: 5,
            stopTimeoutSeconds: 5
        )
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        
        // Solicita início sob modo ativo e pressão crítica
        await coordinator.startService(id)
        
        let runtime = try XCTUnwrap(coordinator.services.first)
        
        // Em modo activeAdmission com pressão crítica, o serviço NÃO pode iniciar (permanece .stopped)
        XCTAssertEqual(runtime.lifecycleState, .stopped)
        XCTAssertTrue(runtime.lastError?.contains("Início adiado pelo Resource Guard") == true)
    }
    
    // 03. Active Admission Blocks Start on Unknown Metrics
    func testActiveAdmissionBlocksStartOnUnknownMetrics() async throws {
        let metrics = ConfigurableMetricsProvider(
            totalRAM: nil,
            freeRAM: nil,
            usedRAM: nil,
            pressure: .unknown
        )
        let rg = ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: metrics),
            initialMode: .activeAdmission
        )
        
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(
            catalog: try CatalogStore(fileURL: catalogURL),
            launchAgent: adapter,
            resourceGuard: rg
        )
        
        let input = ProfileValidator.RawInput(
            name: "Fixture",
            label: label,
            plistPath: plistURL.path,
            executablePath: "/usr/bin/python3",
            workingDirectory: workURL.path,
            readinessURLString: "http://127.0.0.1:\(port)/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "orquestrador-fixture",
            activityURLString: "http://127.0.0.1:\(port)/queue",
            openURLString: "http://127.0.0.1:\(port)/",
            readinessTimeoutSeconds: 5,
            stopTimeoutSeconds: 5
        )
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        
        await coordinator.startService(id)
        
        let runtime = try XCTUnwrap(coordinator.services.first)
        
        XCTAssertEqual(runtime.lifecycleState, .stopped)
        XCTAssertTrue(runtime.lastError?.contains("Início prevenido pelo Resource Guard") == true)
    }
    
    // 04. Restart Re-evaluates Admission Control
    func testRestartReevaluatesAdmissionControl() async throws {
        let metrics = ConfigurableMetricsProvider(pressure: .normal)
        let rg = ResourceGuardCoordinator(
            monitor: ResourceMonitor(provider: metrics),
            initialMode: .activeAdmission
        )
        
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(
            catalog: try CatalogStore(fileURL: catalogURL),
            launchAgent: adapter,
            resourceGuard: rg
        )
        
        let input = ProfileValidator.RawInput(
            name: "Fixture",
            label: label,
            plistPath: plistURL.path,
            executablePath: "/usr/bin/python3",
            workingDirectory: workURL.path,
            readinessURLString: "http://127.0.0.1:\(port)/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "orquestrador-fixture",
            activityURLString: "http://127.0.0.1:\(port)/queue",
            openURLString: "http://127.0.0.1:\(port)/",
            readinessTimeoutSeconds: 5,
            stopTimeoutSeconds: 5
        )
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        
        ownsPossibleJob = true
        // 1. Inicia sob condições normais -> .ready
        await coordinator.startService(id)
        let runtime = try XCTUnwrap(coordinator.services.first)
        XCTAssertEqual(runtime.lifecycleState, .ready)
        
        // 2. Agora registramos 2 jobs pesados para estourar o limite de admissão
        _ = await rg.registerHeavyJob(serviceLabel: "other1", kind: .diffusionGeneration, description: "Heavy 1")
        _ = await rg.registerHeavyJob(serviceLabel: "other2", kind: .benchmarkRun, description: "Heavy 2")
        
        // 3. Executa restart: deve parar o serviço e, ao tentar re-iniciar, ser bloqueado pelo limite de admissão
        await coordinator.restartService(id, userConfirmedIdle: true)
        
        XCTAssertEqual(runtime.lifecycleState, .stopped)
        XCTAssertTrue(runtime.lastError?.contains("Início adiado pelo Resource Guard") == true)
        ownsPossibleJob = false
    }
}
