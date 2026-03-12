import Combine
import SwiftUI
import UIKit

struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeUIView(context: Context) -> FocusAwareTextField {
        let textField = FocusAwareTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.placeholder = placeholder
        textField.returnKeyType = .done
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
        textField.font = resolvedFont(size: 16)
        textField.text = text
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: FocusAwareTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    private func resolvedFont(size: CGFloat) -> UIFont {
        if let name = AppTypography.resolvedFontName(for: size),
           let font = UIFont(name: name, size: size) {
            return font
        }

        return .systemFont(ofSize: size)
    }
}

extension AutoFocusTextField {
    final class FocusAwareTextField: UITextField {
        private var hasAutoFocused = false

        override func didMoveToWindow() {
            super.didMoveToWindow()

            guard window != nil, !hasAutoFocused else { return }
            hasAutoFocused = true

            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, !self.isFirstResponder else {
                    return
                }

                self.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}
