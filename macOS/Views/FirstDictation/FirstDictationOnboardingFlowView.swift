import SwiftUI

struct FirstDictationOnboardingFlowView: View {
    enum Completion {
        case completed
        case skipped
    }

    private enum Step: Hashable {
        case intro
        case practice
    }

    @ObservedObject private var transcriptionManager = AppServiceRegistry.shared.transcriptionManager
    @StateObject private var practiceState = FirstDictationPracticeState()
    @State private var step: Step = .intro
    @State private var containerSize = FirstDictationOnboardingWindowMetrics.introSize
    @FocusState private var isTextFieldFocused: Bool

    let onWindowSizeChange: (CGSize, @escaping () -> Void) -> Void
    let onComplete: (Completion) -> Void

    var body: some View {
        ZStack {
            switch step {
            case .intro:
                FirstDictationIntroView(
                    onTry: startPractice,
                    onSkip: { onComplete(.skipped) }
                )
                .frame(
                    width: FirstDictationOnboardingWindowMetrics.introSize.width,
                    height: FirstDictationOnboardingWindowMetrics.introSize.height
                )
            case .practice:
                FirstDictationPracticeView(
                    text: $practiceState.text,
                    isTextFieldFocused: $isTextFieldFocused,
                    hasSucceeded: practiceState.hasReceivedFirstDictation,
                    onFinish: { onComplete(.completed) }
                )
                .frame(
                    width: FirstDictationOnboardingWindowMetrics.practiceSize.width,
                    height: FirstDictationOnboardingWindowMetrics.practiceSize.height
                )
            }
        }
        .id(step)
        .transition(.opacity)
        .frame(width: containerSize.width, height: containerSize.height)
        .background(MacAppTheme.screenBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onChange(of: transcriptionManager.successfulDictationRevision) { revision in
            guard step == .practice else { return }
            practiceState.captureExpectedDictationIfNeeded(
                revision: revision,
                latestTranscription: transcriptionManager.lastTranscription
            )
        }
    }

    private func startPractice() {
        practiceState.startPractice(
            baselineDictationRevision: transcriptionManager.successfulDictationRevision
        )
        containerSize = FirstDictationOnboardingWindowMetrics.practiceSize
        onWindowSizeChange(FirstDictationOnboardingWindowMetrics.practiceSize) {
            withAnimation(.easeInOut(duration: 0.18)) {
                step = .practice
            }
            isTextFieldFocused = true
        }
    }
}
