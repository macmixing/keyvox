import CoreGraphics
import Testing
@testable import KeyVox_iOS

@MainActor
struct AppHapticsDecisionTests {
    @Test func tabSelectionChangeEmitsLightOnlyWhenTabChanges() {
        #expect(
            MainTabHapticsDecision.eventForSelectionChange(
                previous: .home,
                current: .dictionary
            ) == .light
        )
        #expect(
            MainTabHapticsDecision.eventForSelectionChange(
                previous: .home,
                current: .home
            ) == nil
        )
    }

    @Test func edgeSwipeBoundaryEmitsWarningOnlyAtEnds() {
        #expect(
            MainTabHapticsDecision.eventForEdgeSwipeAttempt(
                currentTab: .home,
                edge: .leading,
                horizontalDistance: 80
            ) == .warning
        )
        #expect(
            MainTabHapticsDecision.eventForEdgeSwipeAttempt(
                currentTab: .settings,
                edge: .trailing,
                horizontalDistance: -80
            ) == .warning
        )
        #expect(
            MainTabHapticsDecision.eventForEdgeSwipeAttempt(
                currentTab: .dictionary,
                edge: .leading,
                horizontalDistance: 80
            ) == nil
        )
        #expect(
            MainTabHapticsDecision.eventForEdgeSwipeAttempt(
                currentTab: .home,
                edge: .leading,
                horizontalDistance: -80
            ) == nil
        )
    }

    @Test func sessionToggleDecisionOnlyEmitsOnActualStateTransition() {
        #expect(SessionToggleHapticsDecision.event(previousIsEnabled: nil, currentIsEnabled: true) == nil)
        #expect(SessionToggleHapticsDecision.event(previousIsEnabled: true, currentIsEnabled: true) == nil)
        #expect(SessionToggleHapticsDecision.event(previousIsEnabled: false, currentIsEnabled: true) == .success)
        #expect(SessionToggleHapticsDecision.event(previousIsEnabled: true, currentIsEnabled: false) == .warning)
    }

    @Test func onboardingStepCompletionOnlyEmitsSuccessOnIncompleteToComplete() {
        #expect(OnboardingStepCompletionHapticsDecision.event(previousIsCompleted: nil, currentIsCompleted: true) == nil)
        #expect(OnboardingStepCompletionHapticsDecision.event(previousIsCompleted: false, currentIsCompleted: true) == .success)
        #expect(OnboardingStepCompletionHapticsDecision.event(previousIsCompleted: true, currentIsCompleted: true) == nil)
        #expect(OnboardingStepCompletionHapticsDecision.event(previousIsCompleted: true, currentIsCompleted: false) == nil)
    }

    @Test func dictionarySaveDecisionMatchesAddSuccessAndFailureRules() {
        #expect(DictionarySaveHapticsDecision.successEvent(isAddingNewWord: true) == .success)
        #expect(DictionarySaveHapticsDecision.successEvent(isAddingNewWord: false) == nil)
        #expect(DictionarySaveHapticsDecision.failureEvent() == .warning)
    }
}
