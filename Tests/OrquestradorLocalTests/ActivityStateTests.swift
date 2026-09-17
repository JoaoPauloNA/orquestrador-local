import XCTest
@testable import OrquestradorLocal

final class ActivityStateTests: XCTestCase {
    // T10: busy is blocked; unknown/not-supported require a separate explicit stop action.
    func testStopDecisionsKeepUnknownDistinctFromIdle() {
        XCTAssertEqual(ActivityState.idle.stopDecision(userConfirmedIdle: false), .allowed)
        XCTAssertEqual(ActivityState.busy(queueRunning: 1, queuePending: 0).stopDecision(userConfirmedIdle: true), .blockedBusy)
        XCTAssertEqual(ActivityState.unknown.stopDecision(userConfirmedIdle: false), .needsManualConfirmation)
        XCTAssertEqual(ActivityState.unknown.stopDecision(userConfirmedIdle: true), .allowed)
        XCTAssertEqual(ActivityState.notSupported.stopDecision(userConfirmedIdle: false), .needsManualConfirmation)
    }
}
