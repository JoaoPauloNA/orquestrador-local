import XCTest
import Darwin
@testable import OrquestradorLocal

/// Product-level lifecycle test: no mocks, real launchctl + isolated loopback
/// LaunchAgent. Every filesystem and launchd artifact has a UUID ownership tag.
@MainActor
final class FixtureProductIntegrationTests: XCTestCase {
    private var label = ""
    private var plistURL: URL!
    private var workURL: URL!
    private var catalogURL: URL!
    private var port = 0
    private var ownsPlist = false
    /// A UUID label plus a plist written by this test makes any registered job
    /// ours. Mark this before the first awaited lifecycle call: bootstrap can
    /// register it and then the subsequent kickstart/readiness can fail.
    private var ownsPossibleJob = false

    override func setUpWithError() throws {
        do {
            let token = UUID().uuidString.lowercased()
            label = "local.orquestrador.fixture.\(token)"
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

    func testCoordinatorControlsOwnedFixtureAndPreservesForeignLabel() async throws {
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(catalog: try CatalogStore(fileURL: catalogURL), launchAgent: adapter)
        let input = ProfileValidator.RawInput(name: "Fixture", label: label, plistPath: plistURL.path, executablePath: "/usr/bin/python3", workingDirectory: workURL.path, readinessURLString: "http://127.0.0.1:\(port)/health", readinessIdentityKind: .bodyContains, readinessIdentityValue: "orquestrador-fixture", activityURLString: "http://127.0.0.1:\(port)/queue", openURLString: "http://127.0.0.1:\(port)/", readinessTimeoutSeconds: 5, stopTimeoutSeconds: 5)
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        ownsPossibleJob = true
        await coordinator.startService(id)
        let runtime = try XCTUnwrap(coordinator.services.first)
        let fixtureError = (try? String(contentsOf: workURL.appendingPathComponent("err.log"), encoding: .utf8)) ?? "sem stderr"
        XCTAssertTrue(fixtureError.isEmpty, "Fixture stderr: \(fixtureError)")
        XCTAssertNil(runtime.lastError, "Fixture start error: \(runtime.lastError ?? "none")")
        XCTAssertEqual(runtime.lifecycleState, .ready)
        XCTAssertEqual(runtime.activityState, .idle)

        // A busy queue blocks the coordinator's owned graceful stop.
        try Data("busy\n".utf8).write(to: workURL.appendingPathComponent("activity.txt"), options: .atomic)
        await coordinator.stopService(id, userConfirmedIdle: false)
        XCTAssertEqual(runtime.lifecycleState, .ready)
        XCTAssertTrue(runtime.activityState.isBusy)

        try Data("idle\n".utf8).write(to: workURL.appendingPathComponent("activity.txt"), options: .atomic)
        await coordinator.stopService(id, userConfirmedIdle: false)
        XCTAssertEqual(runtime.lifecycleState, .stopped)
        ownsPossibleJob = false
        let status = await adapter.observe(label: label, domain: .gui)
        if case .absent = status { } else { XCTFail("Owned fixture must be unloaded") }
    }

    /// Regression for the old gap: bootstrap may have registered this owned
    /// label before readiness/start reports an error. Cleanup must still boot it
    /// out and remove only the test's UUID-tagged files.
    func testBootstrapThenReadinessFailureCleansOwnedJob() async throws {
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(catalog: try CatalogStore(fileURL: catalogURL), launchAgent: adapter)
        let unreachablePort = try reserveLoopbackPort()
        let input = ProfileValidator.RawInput(name: "Fixture failure", label: label, plistPath: plistURL.path, executablePath: "/usr/bin/python3", workingDirectory: workURL.path, readinessURLString: "http://127.0.0.1:\(unreachablePort)/health", readinessIdentityKind: .bodyContains, readinessIdentityValue: "orquestrador-fixture", activityURLString: "", openURLString: "http://127.0.0.1:\(unreachablePort)/", readinessTimeoutSeconds: 5, stopTimeoutSeconds: 5)
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        ownsPossibleJob = true
        await coordinator.startService(id)
        XCTAssertEqual(coordinator.services.first?.lifecycleState, .error)
        cleanupOwnedArtifacts()
        ownsPossibleJob = false
        if case .absent = await adapter.observe(label: label, domain: .gui) { } else { XCTFail("Partially started owned job leaked") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistURL.path))
    }

    func testConcurrentStartAndReopenReconcileOwnedFixture() async throws {
        let adapter = LaunchAgentAdapter()
        let catalog = try CatalogStore(fileURL: catalogURL)
        let coordinator = OrchestrationCoordinator(catalog: catalog, launchAgent: adapter)
        let input = ProfileValidator.RawInput(name: "Fixture reopen", label: label, plistPath: plistURL.path, executablePath: "/usr/bin/python3", workingDirectory: workURL.path, readinessURLString: "http://127.0.0.1:\(port)/health", readinessIdentityKind: .bodyContains, readinessIdentityValue: "orquestrador-fixture", activityURLString: "http://127.0.0.1:\(port)/queue", openURLString: "http://127.0.0.1:\(port)/", readinessTimeoutSeconds: 5, stopTimeoutSeconds: 5)
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        ownsPossibleJob = true
        async let first: Void = coordinator.startService(id)
        async let second: Void = coordinator.startService(id)
        _ = await (first, second)
        XCTAssertEqual(coordinator.services.first?.lifecycleState, .ready)

        let reopened = OrchestrationCoordinator(catalog: try CatalogStore(fileURL: catalogURL), launchAgent: adapter)
        await reopened.start()
        XCTAssertEqual(reopened.services.first?.lifecycleState, .ready, "A new product coordinator reconciles the existing owned job")
        await reopened.stopService(try XCTUnwrap(reopened.services.first?.id), userConfirmedIdle: false)
        ownsPossibleJob = false
    }

    func testExecutableMismatchBlocksStopAndPreservesRunningOwnedFixture() async throws {
        let adapter = LaunchAgentAdapter()
        let coordinator = OrchestrationCoordinator(catalog: try CatalogStore(fileURL: catalogURL), launchAgent: adapter)
        let input = ProfileValidator.RawInput(name: "Fixture mismatch", label: label, plistPath: plistURL.path, executablePath: "/usr/bin/python3", workingDirectory: workURL.path, readinessURLString: "http://127.0.0.1:\(port)/health", readinessIdentityKind: .bodyContains, readinessIdentityValue: "orquestrador-fixture", activityURLString: "", openURLString: "http://127.0.0.1:\(port)/", readinessTimeoutSeconds: 5, stopTimeoutSeconds: 5)
        try await coordinator.register(input: input)
        let id = try XCTUnwrap(coordinator.services.first?.id)
        ownsPossibleJob = true
        await coordinator.startService(id)
        XCTAssertEqual(coordinator.services.first?.lifecycleState, .ready)
        var changed = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as! [String: Any]
        changed["ProgramArguments"] = ["/bin/sh"]
        try PropertyListSerialization.data(fromPropertyList: changed, format: .xml, options: 0).write(to: plistURL, options: .atomic)
        await coordinator.stopService(id, userConfirmedIdle: false)
        XCTAssertEqual(coordinator.services.first?.lifecycleState, .unknown)
        if case .running = await adapter.observe(label: label, domain: .gui) { } else { XCTFail("Mismatch must not unload the still-running job") }
    }

    /// The cleanup path operates on the exact plist it created; a preexisting
    /// unrelated file is deliberately outside those ownership flags.
    func testPreexistingForeignArtifactIsPreserved() throws {
        let foreign = workURL.deletingLastPathComponent().appendingPathComponent("foreign-\(UUID().uuidString).plist")
        try Data("foreign".utf8).write(to: foreign, options: .atomic)
        defer { try? FileManager.default.removeItem(at: foreign) }
        cleanupOwnedArtifacts()
        ownsPossibleJob = false; ownsPlist = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    private func cleanupOwnedArtifacts() {
        if ownsPossibleJob, !label.isEmpty {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl"); process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
            try? process.run(); process.waitUntilExit()
        }
        if ownsPlist, let plistURL { try? FileManager.default.removeItem(at: plistURL) }
        if let workURL { try? FileManager.default.removeItem(at: workURL) }
    }

    private func reserveLoopbackPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EADDRNOTAVAIL) }
        defer { close(fd) }
        var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET); address.sin_port = 0; address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let result = withUnsafePointer(to: &address) { pointer in pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard result == 0 else { throw POSIXError(.EADDRINUSE) }
        var bound = sockaddr_in(); var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &size) } }
        guard nameResult == 0 else { throw POSIXError(.EADDRNOTAVAIL) }
        return Int(UInt16(bigEndian: bound.sin_port))
    }
}
