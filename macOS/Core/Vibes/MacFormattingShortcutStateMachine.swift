import Carbon.HIToolbox
import Cocoa
import KeyVoxCore

struct MacFormattingShortcutStateMachine {
    struct KeyDownDecision: Equatable {
        let shouldConsume: Bool
        let action: DictationDeterministicControlKind?
    }

    private var modifierState = KeyboardModifierStateMachine()
    private var consumedKeyCodes: Set<CGKeyCode> = []
    private(set) var triggerBinding: AppSettingsStore.TriggerBinding
    private(set) var hasCompletedOnboarding: Bool
    private(set) var isRuntimeEnabled = true

    init(
        triggerBinding: AppSettingsStore.TriggerBinding,
        hasCompletedOnboarding: Bool
    ) {
        self.triggerBinding = triggerBinding
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    mutating func updateModifier(keyCode: CGKeyCode, flags: NSEvent.ModifierFlags) {
        modifierState.update(keyCode: keyCode, flags: flags)
    }

    mutating func handleKeyDown(
        keyCode: CGKeyCode,
        isRepeat: Bool
    ) -> KeyDownDecision {
        guard hasCompletedOnboarding,
              isRuntimeEnabled,
              modifierState.isTriggerPressed(binding: triggerBinding),
              let kind = Self.formattingKind(for: keyCode) else {
            return KeyDownDecision(shouldConsume: false, action: nil)
        }

        let isNewPress = consumedKeyCodes.insert(keyCode).inserted
        return KeyDownDecision(
            shouldConsume: true,
            action: isRepeat || isNewPress == false ? nil : kind
        )
    }

    mutating func handleKeyUp(keyCode: CGKeyCode) -> Bool {
        consumedKeyCodes.remove(keyCode) != nil
    }

    mutating func updateTriggerBinding(_ binding: AppSettingsStore.TriggerBinding) {
        triggerBinding = binding
    }

    mutating func updateOnboardingState(_ isComplete: Bool) {
        hasCompletedOnboarding = isComplete
    }

    mutating func setRuntimeEnabled(_ isEnabled: Bool) {
        isRuntimeEnabled = isEnabled
    }

    static func formattingKind(for keyCode: CGKeyCode) -> DictationDeterministicControlKind? {
        switch Int(keyCode) {
        case kVK_ANSI_L:
            return .lists
        case kVK_ANSI_P:
            return .paragraphs
        default:
            return nil
        }
    }
}
