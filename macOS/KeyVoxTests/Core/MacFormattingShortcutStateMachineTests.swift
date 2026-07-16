import AppKit
import Carbon.HIToolbox
import KeyVoxCore
import XCTest
@testable import KeyVox

@MainActor
final class MacFormattingShortcutStateMachineTests: XCTestCase {
    func testEveryTriggerBindingRecognizesListAndParagraphKeys() {
        for trigger in triggerCases {
            var state = makeState(binding: trigger.binding)
            state.updateModifier(keyCode: trigger.keyCode, flags: trigger.flags)

            let listDecision = state.handleKeyDown(
                keyCode: CGKeyCode(kVK_ANSI_L),
                isRepeat: false
            )
            XCTAssertEqual(
                listDecision,
                .init(shouldConsume: true, action: .lists),
                "Failed list shortcut for \(trigger.binding)"
            )
            XCTAssertTrue(state.handleKeyUp(keyCode: CGKeyCode(kVK_ANSI_L)))

            let paragraphDecision = state.handleKeyDown(
                keyCode: CGKeyCode(kVK_ANSI_P),
                isRepeat: false
            )
            XCTAssertEqual(
                paragraphDecision,
                .init(shouldConsume: true, action: .paragraphs),
                "Failed paragraph shortcut for \(trigger.binding)"
            )
            XCTAssertTrue(state.handleKeyUp(keyCode: CGKeyCode(kVK_ANSI_P)))
        }
    }

    func testUnrelatedKeyIsNotConsumed() {
        var state = makeState(binding: .leftOption)
        state.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftOption,
            flags: [.option]
        )

        let decision = state.handleKeyDown(
            keyCode: CGKeyCode(kVK_ANSI_K),
            isRepeat: false
        )

        XCTAssertEqual(decision, .init(shouldConsume: false, action: nil))
        XCTAssertFalse(state.handleKeyUp(keyCode: CGKeyCode(kVK_ANSI_K)))
    }

    func testRepeatAndDuplicateKeyDownAreConsumedWithoutAnotherAction() {
        var state = makeState(binding: .leftCommand)
        state.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftCommand,
            flags: [.command]
        )
        let keyCode = CGKeyCode(kVK_ANSI_L)

        let initial = state.handleKeyDown(keyCode: keyCode, isRepeat: false)
        let repeatDecision = state.handleKeyDown(keyCode: keyCode, isRepeat: true)
        let duplicateDecision = state.handleKeyDown(keyCode: keyCode, isRepeat: false)

        XCTAssertEqual(initial.action, .lists)
        XCTAssertEqual(repeatDecision, .init(shouldConsume: true, action: nil))
        XCTAssertEqual(duplicateDecision, .init(shouldConsume: true, action: nil))
        XCTAssertTrue(state.handleKeyUp(keyCode: keyCode))
        XCTAssertFalse(state.handleKeyUp(keyCode: keyCode))
    }

    func testLeftAndRightBindingsRemainDistinct() {
        var state = makeState(binding: .rightOption)
        state.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftOption,
            flags: [.option]
        )

        XCTAssertFalse(state.handleKeyDown(
            keyCode: CGKeyCode(kVK_ANSI_P),
            isRepeat: false
        ).shouldConsume)

        state.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.rightOption,
            flags: [.option]
        )
        XCTAssertEqual(
            state.handleKeyDown(
                keyCode: CGKeyCode(kVK_ANSI_P),
                isRepeat: false
            ).action,
            .paragraphs
        )
    }

    func testRuntimeAndOnboardingGatesPreventConsumption() {
        var onboardingState = MacFormattingShortcutStateMachine(
            triggerBinding: .leftControl,
            hasCompletedOnboarding: false
        )
        onboardingState.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftControl,
            flags: [.control]
        )
        XCTAssertFalse(onboardingState.handleKeyDown(
            keyCode: CGKeyCode(kVK_ANSI_L),
            isRepeat: false
        ).shouldConsume)

        var runtimeState = makeState(binding: .leftControl)
        runtimeState.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftControl,
            flags: [.control]
        )
        runtimeState.setRuntimeEnabled(false)
        XCTAssertFalse(runtimeState.handleKeyDown(
            keyCode: CGKeyCode(kVK_ANSI_L),
            isRepeat: false
        ).shouldConsume)
    }

    func testRuntimeDisableAfterChordStillConsumesMatchingKeyUp() {
        var state = makeState(binding: .leftControl)
        state.updateModifier(
            keyCode: KeyboardModifierStateMachine.KeyCode.leftControl,
            flags: [.control]
        )
        let keyCode = CGKeyCode(kVK_ANSI_P)

        XCTAssertTrue(state.handleKeyDown(keyCode: keyCode, isRepeat: false).shouldConsume)
        state.setRuntimeEnabled(false)

        XCTAssertTrue(state.handleKeyUp(keyCode: keyCode))
        XCTAssertFalse(state.handleKeyUp(keyCode: keyCode))
    }

    func testMonitorRestoresBothDisabledEventTapConditions() {
        XCTAssertTrue(MacFormattingShortcutMonitor.shouldRestoreEventTap(for: .tapDisabledByTimeout))
        XCTAssertTrue(MacFormattingShortcutMonitor.shouldRestoreEventTap(for: .tapDisabledByUserInput))
        XCTAssertFalse(MacFormattingShortcutMonitor.shouldRestoreEventTap(for: .keyDown))
    }

    private var triggerCases: [(
        binding: AppSettingsStore.TriggerBinding,
        keyCode: CGKeyCode,
        flags: NSEvent.ModifierFlags
    )] {
        [
            (.leftOption, KeyboardModifierStateMachine.KeyCode.leftOption, .option),
            (.rightOption, KeyboardModifierStateMachine.KeyCode.rightOption, .option),
            (.leftCommand, KeyboardModifierStateMachine.KeyCode.leftCommand, .command),
            (.rightCommand, KeyboardModifierStateMachine.KeyCode.rightCommand, .command),
            (.leftControl, KeyboardModifierStateMachine.KeyCode.leftControl, .control),
            (.rightControl, KeyboardModifierStateMachine.KeyCode.rightControl, .control),
            (.function, KeyboardModifierStateMachine.KeyCode.function, .function),
        ]
    }

    private func makeState(
        binding: AppSettingsStore.TriggerBinding
    ) -> MacFormattingShortcutStateMachine {
        MacFormattingShortcutStateMachine(
            triggerBinding: binding,
            hasCompletedOnboarding: true
        )
    }
}
