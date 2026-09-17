import XCTest
@testable import OrquestradorLocal

final class LaunchAgentAdapterTests: XCTestCase {
    private let python = URL(fileURLWithPath: "/usr/bin/python3")

    func testDrainsSaturatedStdoutAndStderrWithoutDeadlock() async {
        let adapter = LaunchAgentAdapter(executableURL: python, commandTimeout: 3, maximumOutputBytes: 512)
        let result = await adapter.runCommandForTesting(["-c", "import sys; sys.stdout.write('o'*200000); sys.stderr.write('e'*200000)"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertTrue(result.outputTruncated)
        XCTAssertLessThanOrEqual(result.stdout.utf8.count, 512)
        XCTAssertLessThanOrEqual(result.stderr.utf8.count, 512)
    }

    func testObservationHelperTimesOutWithoutBlockingCaller() async {
        let adapter = LaunchAgentAdapter(executableURL: python, commandTimeout: 0.25, maximumOutputBytes: 1024)
        let started = Date()
        let result = await adapter.runCommandForTesting(["-c", "import time; time.sleep(5)"])
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2, "Bounded helper must not stall the UI caller")
    }

    func testOutputLimitStillAllowsSuccessfulCommand() async {
        let adapter = LaunchAgentAdapter(executableURL: python, commandTimeout: 3, maximumOutputBytes: 16)
        let result = await adapter.runCommandForTesting(["-c", "print('x'*1000)"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.outputTruncated)
        XCTAssertLessThanOrEqual(result.stdout.utf8.count, 16)
    }

    func testCallerCancellationTerminatesOnlyItsHelper() async {
        let adapter = LaunchAgentAdapter(executableURL: python, commandTimeout: 10, maximumOutputBytes: 1024)
        let task = Task { await adapter.runCommandForTesting(["-c", "import time; time.sleep(10)"]) }
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()
        let result = await task.value
        XCTAssertTrue(result.cancelled)
        XCTAssertFalse(result.timedOut)
        XCTAssertNotEqual(result.exitCode, 0)
    }
}
