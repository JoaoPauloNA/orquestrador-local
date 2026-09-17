import XCTest
@testable import OrquestradorLocal

final class StateMachineTests: XCTestCase {

    // T03-A: Valid transitions
    func testValidTransitions() {
        let validPairs: [(ServiceLifecycleState, ServiceLifecycleState)] = [
            (.stopped, .starting),
            (.starting, .ready),
            (.starting, .error),
            (.ready, .stopping),
            (.ready, .error),
            (.stopping, .stopped),
            (.stopping, .error),
            (.error, .starting),
            (.error, .stopped),
        ]
        for (from, to) in validPairs {
            XCTAssertTrue(from.canTransition(to: to),
                "\(from) → \(to) should be valid")
        }
    }

    // T03-B: Invalid transitions — never goes pronto before readiness
    func testInvalidTransitions() {
        let invalidPairs: [(ServiceLifecycleState, ServiceLifecycleState)] = [
            (.stopped, .ready),   // must go through starting
            (.stopped, .stopping),
            (.stopped, .error),   // direct error without attempting start not valid
        ]
        for (from, to) in invalidPairs {
            XCTAssertFalse(from.canTransition(to: to),
                "\(from) → \(to) should be invalid")
        }
    }

    // T03-C: Stop enabled only when ready and owned by the registered supervisor.
    func testStopEnabledStates() {
        XCTAssertTrue(ServiceLifecycleState.ready.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.external.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.stopped.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.starting.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.stopping.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.error.stopEnabled)
        XCTAssertFalse(ServiceLifecycleState.unknown.stopEnabled)
    }

    // T03-D: Start enabled only from stopped/error
    func testStartEnabledStates() {
        XCTAssertTrue(ServiceLifecycleState.stopped.startEnabled)
        XCTAssertTrue(ServiceLifecycleState.error.startEnabled)
        XCTAssertFalse(ServiceLifecycleState.ready.startEnabled)
        XCTAssertFalse(ServiceLifecycleState.starting.startEnabled)
        XCTAssertFalse(ServiceLifecycleState.stopping.startEnabled)
        XCTAssertFalse(ServiceLifecycleState.external.startEnabled)
        XCTAssertFalse(ServiceLifecycleState.unknown.startEnabled)
    }

    // T03-E: Open enabled only from ready
    func testOpenEnabledStates() {
        XCTAssertTrue(ServiceLifecycleState.ready.openEnabled)
        for state: ServiceLifecycleState in [.stopped, .starting, .stopping, .error, .external, .unknown] {
            XCTAssertFalse(state.openEnabled)
        }
    }

    // T03-F: All states have unique labels
    func testUniqueLabels() {
        let labels = ServiceLifecycleState.allCases.map { $0.label }
        let unique = Set(labels)
        XCTAssertEqual(labels.count, unique.count, "All state labels must be unique")
    }

    // T03-G: ActivityState.isBusy and isUnknown are mutually exclusive
    func testActivityStateMutualExclusion() {
        let busy = ActivityState.busy(queueRunning: 1, queuePending: 0)
        XCTAssertTrue(busy.isBusy)
        XCTAssertFalse(busy.isUnknown)

        let unknown = ActivityState.unknown
        XCTAssertFalse(unknown.isBusy)
        XCTAssertTrue(unknown.isUnknown)

        let idle = ActivityState.idle
        XCTAssertFalse(idle.isBusy)
        XCTAssertFalse(idle.isUnknown)
    }

    // T03-H: ActivityState codable round-trip
    func testActivityStateCodable() throws {
        let states: [ActivityState] = [
            .idle,
            .busy(queueRunning: 3, queuePending: 1),
            .unknown,
            .notSupported
        ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ActivityState.self, from: data)
            XCTAssertEqual(state, decoded, "Round-trip failed for \(state)")
        }
    }
}
