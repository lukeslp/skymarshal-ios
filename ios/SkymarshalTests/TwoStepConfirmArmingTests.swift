import XCTest
@testable import SkymarshalCore

final class TwoStepConfirmArmingTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func test_firstActivation_armsAndDoesNotConfirm() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        XCTAssertFalse(machine.isArmed(now: t0))
        XCTAssertEqual(machine.activate(now: t0), .armed)
        XCTAssertTrue(machine.isArmed(now: t0))
    }

    func test_secondActivationWithinWindow_confirmsAndDisarms() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        machine.activate(now: t0)
        XCTAssertEqual(machine.activate(now: t0.addingTimeInterval(9.9)), .confirmed)
        XCTAssertFalse(machine.isArmed(now: t0.addingTimeInterval(9.9)))
    }

    func test_activationAtExactWindowBoundary_confirms() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        machine.activate(now: t0)
        XCTAssertEqual(machine.activate(now: t0.addingTimeInterval(10)), .confirmed)
    }

    func test_activationAfterWindowLapsed_rearmsInsteadOfConfirming() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        machine.activate(now: t0)
        let late = t0.addingTimeInterval(10.1)
        XCTAssertFalse(machine.isArmed(now: late))
        XCTAssertEqual(machine.activate(now: late), .armed)
        // The re-arm opens a fresh window from the late activation.
        XCTAssertEqual(machine.activate(now: late.addingTimeInterval(5)), .confirmed)
    }

    func test_reset_disarmsWithoutConfirming() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        machine.activate(now: t0)
        machine.reset()
        XCTAssertFalse(machine.isArmed(now: t0))
        // Next activation after a reset must arm again, never confirm.
        XCTAssertEqual(machine.activate(now: t0.addingTimeInterval(1)), .armed)
    }

    func test_noSingleActivationConfirmPath_fromColdStart() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        // From any disarmed state, one activation can only ever arm.
        for offset in [0.0, 60.0, 3_600.0] {
            machine.reset()
            XCTAssertEqual(machine.activate(now: t0.addingTimeInterval(offset)), .armed)
        }
    }

    func test_confirmDisarms_soThirdActivationArmsAgain() {
        var machine = TwoStepConfirmArming(windowSeconds: 10)
        machine.activate(now: t0)
        _ = machine.activate(now: t0.addingTimeInterval(1))
        XCTAssertEqual(machine.activate(now: t0.addingTimeInterval(2)), .armed)
    }
}
