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
    @State private var step: Step = .intro
    @State private var containerSize = FirstDictationOnboardingWindowMetrics.introSize
    @State private var text = ""
    @State private var baselineDictationRevision = 0
    @State private var expectedDictationText = ""
    @State private var hasReceivedFirstDictation = false
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
                    text: $text,
                    isTextFieldFocused: $isTextFieldFocused,
                    hasSucceeded: hasReceivedFirstDictation,
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
            captureExpectedDictationIfNeeded(
                revision: revision,
                latestTranscription: transcriptionManager.lastTranscription
            )
        }
    }

    private func startPractice() {
        baselineDictationRevision = transcriptionManager.successfulDictationRevision
        text = ""
        expectedDictationText = ""
        hasReceivedFirstDictation = false
        containerSize = FirstDictationOnboardingWindowMetrics.practiceSize
        onWindowSizeChange(FirstDictationOnboardingWindowMetrics.practiceSize) {
            withAnimation(.easeInOut(duration: 0.18)) {
                step = .practice
            }
            isTextFieldFocused = true
        }
    }

    private func captureExpectedDictationIfNeeded(revision: Int, latestTranscription: String) {
        guard step == .practice else { return }
        let trimmed = latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, revision > baselineDictationRevision else { return }

        expectedDictationText = latestTranscription
        completePracticeIfNeeded(with: text)
    }

    private func completePracticeIfNeeded(with currentText: String) {
        guard step == .practice, hasReceivedFirstDictation == false else { return }
        let expectedText = normalizedFirstDictationText(expectedDictationText)
        guard !expectedText.isEmpty else { return }
        let fieldText = normalizedFirstDictationText(currentText)
        guard fieldText.range(
            of: expectedText,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        ) != nil else { return }

        hasReceivedFirstDictation = true
    }

    private func normalizedFirstDictationText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
