import SwiftUI

/// One autocorrecting text area, a clear button the baseline runner taps between sentences,
/// fill buttons that fill it with text to hold delete over, and hide and show buttons that
/// dismiss the keyboard and bring it back. No other button takes focus, so the keyboard stays up.
struct BaselineInputView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Clear") { text = "" }
                    .accessibilityIdentifier("clear")
                Button("Hide") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("hide")
                Button("Show") { NotificationCenter.default.post(name: TypingTextView.showKeyboard, object: nil) }
                    .accessibilityIdentifier("show")
                Spacer()
                fillButton("Lines", text: DeletionSampleText.lines())
                fillButton("Long", text: DeletionSampleText.longWords())
                fillButton("Fill", text: DeletionSampleText.make())
            }
            TypingTextView(text: $text)
                .frame(maxWidth: .infinity, minHeight: 160)
                .border(Color.secondary)
            Spacer()
        }
        .padding()
    }

    private func fillButton(_ title: String, text sample: String) -> some View {
        Button(title) {
            text = sample
            DeletionTimeline.shared.reset(to: sample)
        }
        .accessibilityIdentifier(title.lowercased())
    }
}
