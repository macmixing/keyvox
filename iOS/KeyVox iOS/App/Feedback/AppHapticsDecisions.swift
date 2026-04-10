import CoreGraphics
import Foundation

enum AppHapticEvent: Equatable, Sendable {
    case light
    case medium
    case selection
    case success
    case warning
}

enum MainTabHapticsDecision {
    static func eventForSelectionChange(
        previous: ContainingAppTab,
        current: ContainingAppTab
    ) -> AppHapticEvent? {
        previous == current ? nil : .light
    }

    static func eventForEdgeSwipeAttempt(
        currentTab: ContainingAppTab,
        edge: MainTabView.Edge,
        horizontalDistance: CGFloat
    ) -> AppHapticEvent? {
        switch edge {
        case .leading:
            let isBlockedSwipe = horizontalDistance >= 0
            return currentTab.previous == nil && isBlockedSwipe ? .warning : nil
        case .trailing:
            let isBlockedSwipe = horizontalDistance <= 0
            return currentTab.next == nil && isBlockedSwipe ? .warning : nil
        }
    }
}

enum SessionToggleHapticsDecision {
    static func event(previousIsEnabled: Bool?, currentIsEnabled: Bool) -> AppHapticEvent? {
        guard let previousIsEnabled, previousIsEnabled != currentIsEnabled else {
            return nil
        }

        return currentIsEnabled ? .success : .warning
    }
}

enum OnboardingStepCompletionHapticsDecision {
    static func event(previousIsCompleted: Bool?, currentIsCompleted: Bool) -> AppHapticEvent? {
        guard let previousIsCompleted else { return nil }
        return previousIsCompleted == false && currentIsCompleted ? .success : nil
    }
}

enum DictionarySaveHapticsDecision {
    static func successEvent(isAddingNewWord: Bool) -> AppHapticEvent? {
        isAddingNewWord ? .success : nil
    }

    static func failureEvent() -> AppHapticEvent {
        .warning
    }
}
