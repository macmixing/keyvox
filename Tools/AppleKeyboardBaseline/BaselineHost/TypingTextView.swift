import SwiftUI
import UIKit

/// A plain UITextView with system autocorrection on and every other text helper that
/// could rewrite input off: no auto-capitalization, smart punctuation, or inline
/// predictions, so the recorded text reflects autocorrect alone. `SMART_QUOTES=1` turns
/// smart quotes on and `AUTOCAPITALIZE=1` capitalizes sentences, as most apps' text fields
/// do.
struct TypingTextView: UIViewRepresentable {
    /// Posted to give the text view focus again, bringing the keyboard back.
    static let showKeyboard = Notification.Name("TypingTextView.showKeyboard")

    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        let isAutocorrectionDisabled = ProcessInfo.processInfo.environment["DISABLE_AUTOCORRECT"] == "1"
        view.autocorrectionType = isAutocorrectionDisabled ? .no : .yes
        view.spellCheckingType = isAutocorrectionDisabled ? .no : .yes
        view.autocapitalizationType = ProcessInfo.processInfo.environment["AUTOCAPITALIZE"] == "1" ? .sentences : .none
        view.smartQuotesType = ProcessInfo.processInfo.environment["SMART_QUOTES"] == "1" ? .yes : .no
        // With KEYBOARD_TYPE=url, a web address field's keyboard, with its web ending key.
        if ProcessInfo.processInfo.environment["KEYBOARD_TYPE"] == "url" {
            view.keyboardType = .URL
        }
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.inlinePredictionType = .no
        view.accessibilityIdentifier = "input"
        view.delegate = context.coordinator
        if ProcessInfo.processInfo.environment["SMART_DELETE_CHARACTERS"] == "1" {
            DispatchQueue.main.async {
                SmartDeleteCharacterProbe.run(in: view)
            }
        }
        NotificationCenter.default.addObserver(forName: Self.showKeyboard, object: nil, queue: .main) { [weak view] _ in
            view?.becomeFirstResponder()
        }
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
