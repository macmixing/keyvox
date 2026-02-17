import AppKit
import XCTest
@testable import KeyVox

final class KeyboardMonitorStateTests: XCTestCase {
    func testLeftAndRightModifierTransitionsByKeyCode() {
        var state = KeyboardModifierStateMachine()

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftOption,
            flags: [.option]
        )
        XCTAssertTrue(state.leftOptionDown)
        XCTAssertFalse(state.rightOptionDown)

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.rightOption,
            flags: [.option]
        )
        XCTAssertTrue(state.rightOptionDown)

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftCommand,
            flags: [.command]
        )
        XCTAssertTrue(state.leftCommandDown)
        XCTAssertFalse(state.rightCommandDown)

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.rightControl,
            flags: [.control]
        )
        XCTAssertTrue(state.rightControlDown)
    }

    func testAggregateFlagDropClearsStaleSideState() {
        var state = KeyboardModifierStateMachine(
            leftOptionDown: true,
            rightOptionDown: true,
            leftCommandDown: true,
            rightCommandDown: true,
            leftControlDown: true,
            rightControlDown: true,
            fnDown: true
        )

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftOption,
            flags: []
        )

        XCTAssertFalse(state.leftOptionDown)
        XCTAssertFalse(state.rightOptionDown)
        XCTAssertFalse(state.leftCommandDown)
        XCTAssertFalse(state.rightCommandDown)
        XCTAssertFalse(state.leftControlDown)
        XCTAssertFalse(state.rightControlDown)
        XCTAssertFalse(state.fnDown)
    }

    func testTriggerEvaluationForEachBinding() {
        var state = KeyboardModifierStateMachine()
        state.leftOptionDown = true
        state.rightOptionDown = true
        state.leftCommandDown = true
        state.rightCommandDown = true
        state.leftControlDown = true
        state.rightControlDown = true
        state.fnDown = true

        XCTAssertTrue(state.isTriggerPressed(binding: .leftOption))
        XCTAssertTrue(state.isTriggerPressed(binding: .rightOption))
        XCTAssertTrue(state.isTriggerPressed(binding: .leftCommand))
        XCTAssertTrue(state.isTriggerPressed(binding: .rightCommand))
        XCTAssertTrue(state.isTriggerPressed(binding: .leftControl))
        XCTAssertTrue(state.isTriggerPressed(binding: .rightControl))
        XCTAssertTrue(state.isTriggerPressed(binding: .function))
    }

    func testBindingChangeWhileKeyHeldReevaluatesAgainstCurrentState() {
        var state = KeyboardModifierStateMachine()
        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftOption,
            flags: [.option]
        )

        XCTAssertTrue(state.isTriggerPressed(binding: .leftOption))
        XCTAssertFalse(state.isTriggerPressed(binding: .rightOption))

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.rightOption,
            flags: [.option]
        )

        XCTAssertTrue(state.isTriggerPressed(binding: .leftOption))
        XCTAssertTrue(state.isTriggerPressed(binding: .rightOption))
    }

    func testFnTracksAggregateFunctionFlag() {
        var state = KeyboardModifierStateMachine()

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.function,
            flags: [.function]
        )
        XCTAssertTrue(state.fnDown)
        XCTAssertTrue(state.isTriggerPressed(binding: .function))

        state.update(
            keyCode: KeyboardModifierStateMachine.KeyCode.function,
            flags: []
        )
        XCTAssertFalse(state.fnDown)
        XCTAssertFalse(state.isTriggerPressed(binding: .function))
    }
}
