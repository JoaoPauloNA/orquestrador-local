import XCTest
@testable import OrquestradorLocal

final class UXPresentationSafetyTests: XCTestCase {

    // Test that unmonitored (.notSupported) and unverified (.unknown) activity require manual confirmation,
    // whereas standard activity-supported states (.idle, .busy) do not.
    func testRequiresManualIdleConfirmationDistinction() {
        XCTAssertTrue(ActivityState.notSupported.requiresManualIdleConfirmation,
                      "notSupported must require manual idle confirmation before stopping")
        XCTAssertTrue(ActivityState.unknown.requiresManualIdleConfirmation,
                      "unknown must require manual idle confirmation before stopping")
        XCTAssertFalse(ActivityState.idle.requiresManualIdleConfirmation,
                      "idle must not require manual confirmation")
        XCTAssertFalse(ActivityState.busy(queueRunning: 1, queuePending: 0).requiresManualIdleConfirmation,
                      "busy does not require confirmation because it is directly blocked by isBusy")
    }

    // Safety invariant: busy ALWAYS blocks stop regardless of user confirmation
    func testBusyAlwaysBlocksStopRegardlessOfUserConfirmation() {
        let busyState = ActivityState.busy(queueRunning: 2, queuePending: 1)
        XCTAssertEqual(busyState.stopDecision(userConfirmedIdle: false), .blockedBusy)
        XCTAssertEqual(busyState.stopDecision(userConfirmedIdle: true), .blockedBusy,
                       "User confirmation must never override a busy activity state")
    }

    // Safety invariant: unknown / unmonitored activity stops ONLY when user confirms idle
    func testUnmonitoredActivityStopGatedByManualConfirmation() {
        XCTAssertEqual(ActivityState.notSupported.stopDecision(userConfirmedIdle: false),
                       .needsManualConfirmation,
                       "Stop must be gated when manual confirmation is not provided")
        XCTAssertEqual(ActivityState.notSupported.stopDecision(userConfirmedIdle: true),
                       .allowed,
                       "Stop is allowed only when manual confirmation is provided")

        XCTAssertEqual(ActivityState.unknown.stopDecision(userConfirmedIdle: false),
                       .needsManualConfirmation,
                       "Stop must be gated when manual confirmation is not provided")
        XCTAssertEqual(ActivityState.unknown.stopDecision(userConfirmedIdle: true),
                       .allowed,
                       "Stop is allowed only when manual confirmation is provided")
    }

    // Lifecycle invariant: stop action is enabled ONLY when ready
    func testStopControlEnabledOnlyWhenReady() {
        XCTAssertTrue(ServiceLifecycleState.ready.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.stopped.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.starting.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.stopping.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.error.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.external.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.unknown.stopEnabled)
    }
}
