import SwiftUI

/// One autocorrecting text area and a clear button the baseline runner taps between
/// sentences. The clear button never takes focus, so the system keyboard stays up.
struct BaselineInputView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 12) {
            Button("Clear") { text = "" }
                .accessibilityIdentifier("clear")
            TypingTextView(text: $text)
                .frame(maxWidth: .infinity, minHeight: 160)
                .border(Color.secondary)
            Spacer()
        }
        .padding()
    }
}
