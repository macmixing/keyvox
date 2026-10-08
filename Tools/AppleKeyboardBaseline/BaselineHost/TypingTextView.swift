import SwiftUI
import UIKit

/// A plain UITextView with system autocorrection on and every other text helper that
/// could rewrite input off: no auto-capitalization, smart punctuation, or inline
/// predictions, so the recorded text reflects autocorrect alone.
struct TypingTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        let isAutocorrectionDisabled = ProcessInfo.processInfo.environment["DISABLE_AUTOCORRECT"] == "1"
        view.autocorrectionType = isAutocorrectionDisabled ? .no : .yes
        view.spellCheckingType = isAutocorrectionDisabled ? .no : .yes
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.inlinePredictionType = .no
        view.accessibilityIdentifier = "input"
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
            view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            DeletionTimeline.shared.record(textView.text)
        }
    }
}
