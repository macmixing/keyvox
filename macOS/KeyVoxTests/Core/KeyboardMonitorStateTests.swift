import AppKit
import XCTest
@testable import KeyVox

final class KeyboardMonitorStateTests: XCTestCase {
    func testPhysicalTimestampMatcherIgnoresUnrelatedModifierSamples() {
        let matcher = KeyboardModifierEventTapContext()

        matcher.record(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftCommand,
            timestamp: 10
        )

        XCTAssertNil(matcher.takeTimestamp(
            for: KeyboardModifierStateMachine.KeyCode.rightOption,
            matching: 10
        ))
    }

    func testPhysicalTimestampMatcherDiscardsStaleSampleAndUsesMatchingEvent() {
        let matcher = KeyboardModifierEventTapContext()
        let keyCode = KeyboardModifierStateMachine.KeyCode.rightOption
        matcher.record(keyCode: keyCode, timestamp: 10)
        matcher.record(keyCode: keyCode, timestamp: 20)

        XCTAssertEqual(
            matcher.takeTimestamp(for: keyCode, matching: 20),
            20
        )
    }

    func testPhysicalTimestampMatcherDoesNotConsumeFutureTransition() {
        let matcher = KeyboardModifierEventTapContext()
        let keyCode = KeyboardModifierStateMachine.KeyCode.rightOption
        matcher.record(keyCode: keyCode, timestamp: 10.1)

        XCTAssertNil(matcher.takeTimestamp(
            for: keyCode,
            matching: 10
        ))
        XCTAssertEqual(
            matcher.takeTimestamp(for: keyCode, matching: 10.1),
            10.1
        )
    }

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
