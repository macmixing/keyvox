import Combine
import SwiftUI
import UIKit

struct AutoFocusTextField: UIViewRepresentable {
    private enum Metrics {
        static let baseFontSize: CGFloat = 16
        static let maximumContentSizeCategory = UIContentSizeCategory.accessibilityMedium
    }

    @Binding var text: String
    let placeholder: String
    let allowsTextChanges: Bool
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        placeholder: String,
        allowsTextChanges: Bool = true,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.allowsTextChanges = allowsTextChanges
        self.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            allowsTextChanges: allowsTextChanges,
            onSubmit: onSubmit
        )
    }

    func makeUIView(context: Context) -> FocusAwareTextField {
        let textField = FocusAwareTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.placeholder = placeholder
        textField.returnKeyType = .done
        textField.autocapitalizationType = .sentences
        textField.autocorrectionType = .no
        textField.font = resolvedScaledFont()
        textField.adjustsFontForContentSizeCategory = true
        textField.text = text
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ uiView: FocusAwareTextField, context: Context) {
        context.coordinator.allowsTextChanges = allowsTextChanges

        if uiView.text != text {
            uiView.text = text
        }
    }

    private func resolvedScaledFont() -> UIFont {
        let baseFont: UIFont

        if let name = AppTypography.resolvedFontName(for: Metrics.baseFontSize, variant: .light),
           let font = UIFont(name: name, size: Metrics.baseFontSize) {
            baseFont = font
        } else {
            baseFont = .systemFont(ofSize: Metrics.baseFontSize, weight: .light)
        }

        let fontMetrics = UIFontMetrics(forTextStyle: .body)
        let maximumTraitCollection = UITraitCollection(
            preferredContentSizeCategory: Metrics.maximumContentSizeCategory
        )
        let maximumPointSize = fontMetrics.scaledValue(
            for: Metrics.baseFontSize,
            compatibleWith: maximumTraitCollection
        )

        return fontMetrics.scaledFont(
            for: baseFont,
            maximumPointSize: maximumPointSize
        )
    }
}

extension AutoFocusTextField {
    final class FocusAwareTextField: UITextField {
        private var hasAutoFocused = false

        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            let fittedSize = super.sizeThatFits(size)
            return CGSize(width: size.width, height: fittedSize.height)
        }

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
        var allowsTextChanges: Bool
        private let onSubmit: () -> Void

        init(
            text: Binding<String>,
            allowsTextChanges: Bool,
            onSubmit: @escaping () -> Void
        ) {
            _text = text
            self.allowsTextChanges = allowsTextChanges
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            allowsTextChanges
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}
