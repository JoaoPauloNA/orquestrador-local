import XCTest
@testable import OrquestradorLocal

final class CatalogStoreTests: XCTestCase {

    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("orq-catalog-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    private func makeStore() throws -> CatalogStore {
        try CatalogStore(fileURL: directoryURL.appendingPathComponent("catalog.json"))
    }

    private func makeProfile(label: String = "local.teste.unit") -> ServiceProfile {
        ServiceProfile(
            id: UUID(),
            name: "Teste Unit",
            label: label,
            launchdDomain: .gui,
            plistPath: "/tmp/test.plist",
            executablePath: "/bin/sh",
            workingDirectory: "/tmp",
            controlFingerprint: "synthetic",
            readinessURL: URL(string: "http://127.0.0.1:19765/health")!,
            readinessIdentity: .bodyContains("fixture"),
            activityURL: nil,
            activityRunningKey: nil,
            activityPendingKey: nil,
            openURL: URL(string: "http://127.0.0.1:19765/")!,
            readinessTimeoutSeconds: 30,
            stopTimeoutSeconds: 15,
            description: "Perfil de teste",
            schemaVersion: ServiceProfile.currentSchemaVersion,
            validatedAt: Date()
        )
    }

    // T02-A: Profile persisted and reloaded
    func testProfilePersistenceRoundTrip() async throws {
        let store = try makeStore()
        let profile = makeProfile()
        try await store.add(profile)

        let store2 = try makeStore()
        try await store2.load()
        let loaded = await store2.allProfiles()

        let found = loaded.first { $0.id == profile.id }
        XCTAssertNotNil(found, "Profile should survive persist/reload cycle")
        XCTAssertEqual(found?.name, profile.name)
        XCTAssertEqual(found?.label, profile.label)

        // Cleanup
        try await store.remove(id: profile.id)
    }

    func testReplaceProfileKeepsIDAndUpdatesDeclarativeFields() async throws {
        let store = try makeStore()
        let original = makeProfile(label: "local.replace.test")
        var replacement = makeProfile(label: original.label)
        replacement = ServiceProfile(
            id: replacement.id,
            name: "Perfil atualizado",
            label: replacement.label,
            launchdDomain: replacement.launchdDomain,
            plistPath: replacement.plistPath,
            executablePath: replacement.executablePath,
            workingDirectory: replacement.workingDirectory,
            controlFingerprint: "new-fingerprint",
            readinessURL: replacement.readinessURL,
            readinessIdentity: .bodyContains("updated"),
            activityURL: replacement.activityURL,
            activityRunningKey: replacement.activityRunningKey,
            activityPendingKey: replacement.activityPendingKey,
            openURL: replacement.openURL,
            readinessTimeoutSeconds: replacement.readinessTimeoutSeconds,
            stopTimeoutSeconds: replacement.stopTimeoutSeconds,
            description: replacement.description,
            schemaVersion: replacement.schemaVersion,
            validatedAt: replacement.validatedAt
        )
        try await store.add(original)
        try await store.replace(id: original.id, with: replacement)
        let profiles = await store.allProfiles()
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].id, original.id)
        XCTAssertEqual(profiles[0].name, "Perfil atualizado")
        XCTAssertEqual(profiles[0].controlFingerprint, "new-fingerprint")
        XCTAssertEqual(profiles[0].readinessIdentity, .bodyContains("updated"))
    }

    // T02: the very first successful save creates a recoverable copy; a later
    // torn/corrupt primary must not discard that validated catalog.
    func testFirstSaveSurvivesPrimaryCorruption() async throws {
        let store = try makeStore()
        let profile = makeProfile(label: "local.catalog.first-save.\(UUID().uuidString)")
        try await store.add(profile)
        let primary = directoryURL.appendingPathComponent("catalog.json")
        let backup = directoryURL.appendingPathComponent("catalog.last-valid.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        try Data("{truncated".utf8).write(to: primary)

        let recovered = try makeStore()
        do { try await recovered.load(); XCTFail("Expected recovery notice") }
        catch CatalogError.recoveredFromBackup { }
        let profiles = await recovered.allProfiles()
        XCTAssertEqual(profiles.map(\.id), [profile.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: primary.path), "Recovery never deletes corrupt user data")
    }

    func testNewestSaveIsTheBackupBeforePrimaryReplacement() async throws {
        let store = try makeStore()
        let first = makeProfile(label: "local.catalog.one.\(UUID().uuidString)")
        let second = makeProfile(label: "local.catalog.two.\(UUID().uuidString)")
        try await store.add(first); try await store.add(second)
        let primary = directoryURL.appendingPathComponent("catalog.json")
        try Data("interrupted".utf8).write(to: primary)
        let recovered = try makeStore()
        do { try await recovered.load(); XCTFail("Expected recovery notice") }
        catch CatalogError.recoveredFromBackup { }
        let profiles = await recovered.allProfiles()
        XCTAssertEqual(Set(profiles.map(\.id)), Set([first.id, second.id]))
    }

    // T02-B: Duplicate label rejected
    func testDuplicateLabelRejected() async throws {
        let store = try makeStore()
        let p1 = makeProfile(label: "local.duplicate.test")
        let p2 = makeProfile(label: "local.duplicate.test")

        try await store.add(p1)

        do {
            try await store.add(p2)
            XCTFail("Should have thrown CatalogError.duplicateLabel")
        } catch CatalogError.duplicateLabel(let l) {
            XCTAssertEqual(l, "local.duplicate.test")
        }

        // This must finish before XCTest enters tearDown. A detached Task in a
        // defer races the directory removal and can recreate catalog files.
        try await store.remove(id: p1.id)
    }

    // T02-C: Remove nonexistent throws
    func testRemoveNonexistentThrows() async {
        let store: CatalogStore
        do { store = try makeStore() } catch { return XCTFail("Setup failed: \(error)") }
        do {
            try await store.remove(id: UUID())
            XCTFail("Should throw CatalogError.notFound")
        } catch CatalogError.notFound {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // T14: Event log sanitizes env-like lines
    func testEventLogSanitization() async {
        let log = EventLog()
        let rawMessage = "Process started\nSECRET_KEY=abc123\nReady"
        let event = ServiceEvent(serviceId: UUID(), kind: .started, message: rawMessage)
        await log.append(event)
        let events = await log.recent()
        XCTAssertFalse(events.isEmpty)
        XCTAssertFalse(events[0].message.contains("SECRET_KEY"))
    }

    // T14-B: Event log bounded to 50 events
    func testEventLogBounded() async {
        let log = EventLog(maxCount: 50)
        let id = UUID()
        for i in 0..<60 {
            await log.append(ServiceEvent(serviceId: id, kind: .stateReconciled, message: "event \(i)"))
        }
        let events = await log.all()
        XCTAssertLessThanOrEqual(events.count, 50, "Event log must not exceed maxCount")
        // Most recent events should be present
        XCTAssertTrue(events.last?.message.contains("59") ?? false)
    }
}
