import Combine
import Foundation

@MainActor
final class FirstDictationPracticeState: ObservableObject {
    @Published var text = "" {
        didSet {
            completePracticeIfNeeded()
        }
    }
    @Published private(set) var hasReceivedFirstDictation = false

    private var baselineDictationRevision = 0
    private var expectedDictationText = ""

    func startPractice(baselineDictationRevision: Int) {
        self.baselineDictationRevision = baselineDictationRevision
        expectedDictationText = ""
        hasReceivedFirstDictation = false
        text = ""
    }

    func captureExpectedDictationIfNeeded(revision: Int, latestTranscription: String) {
        let trimmed = latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, revision > baselineDictationRevision else { return }

        expectedDictationText = latestTranscription
        completePracticeIfNeeded()
    }

    private func completePracticeIfNeeded() {
        guard hasReceivedFirstDictation == false else { return }
        let expectedText = normalizedText(expectedDictationText)
        guard !expectedText.isEmpty else { return }
        let fieldText = normalizedText(text)
        guard fieldText.range(
            of: expectedText,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        ) != nil else { return }

        hasReceivedFirstDictation = true
    }

    private func normalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
