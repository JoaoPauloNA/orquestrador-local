import XCTest
@testable import OrquestradorLocal

final class QuotaProbeTests: XCTestCase {
    func testParsesRemainingAndLimitFromExplicitQuota() {
        let data = Data(#"{"quota":{"remaining":37,"limit":100}}"#.utf8)
        XCTAssertEqual(QuotaProbe.parse(data: data), .available(remaining: 37, limit: 100))
    }

    func testDerivesRemainingFromLimitAndUsed() {
        let data = Data(#"{"usage":{"limit":100,"used":28}}"#.utf8)
        XCTAssertEqual(QuotaProbe.parse(data: data), .available(remaining: 72, limit: 100))
    }

    func testRejectsUnknownOrInconsistentSchemas() {
        XCTAssertEqual(QuotaProbe.parse(data: Data(#"{"message":"ok"}"#.utf8)), .unavailable)
        XCTAssertEqual(QuotaProbe.parse(data: Data(#"{"remaining":101,"limit":100}"#.utf8)), .unavailable)
    }

    func testOnlyKnownLocalProxyProfilesAreEligible() {
        let profile = makeProfile(port: 8320, identity: .bodyContains("CLI Proxy API Server"))
        XCTAssertTrue(QuotaProbe.isSupported(profile))
        XCTAssertFalse(QuotaProbe.isSupported(makeProfile(port: 8766, identity: .bodyContains("CLI Proxy API Server"))))
        XCTAssertFalse(QuotaProbe.isSupported(makeProfile(port: 8320, identity: .bodyContains("different service"))))
    }

    func testPresentationDoesNotTreatUnknownAsCapacity() {
        XCTAssertEqual(QuotaState.notChecked.displayText, "N/D")
        XCTAssertEqual(QuotaState.unavailable.displayText, "Não verificável")
    }

    private func makeProfile(port: Int, identity: ReadinessIdentity) -> ServiceProfile {
        ServiceProfile(id: UUID(), name: "Proxy", label: "local.proxy", launchdDomain: .gui, plistPath: "/tmp/x.plist", executablePath: "/bin/sh", workingDirectory: "/tmp", controlFingerprint: "fixture", readinessURL: URL(string: "http://127.0.0.1:\(port)/")!, readinessIdentity: identity, activityURL: nil, activityRunningKey: nil, activityPendingKey: nil, openURL: URL(string: "http://127.0.0.1:\(port)/")!, readinessTimeoutSeconds: 15, stopTimeoutSeconds: 30, description: "", schemaVersion: 1, validatedAt: .now)
    }
}
