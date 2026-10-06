import UIKit

/// What the focused text field lets the letter keyboard do, read from its text traits.
struct KeyboardTypingTraits: Equatable {
    /// The field expects digits first, so the keyboard opens on the number page.
    let prefersNumberPage: Bool
    let allowsPredictions: Bool
    let allowsAutocorrection: Bool
    let autocapitalization: UITextAutocapitalizationType

    init(proxy: UITextDocumentProxy) {
        let keyboardType = proxy.keyboardType ?? .default
        let contentType = proxy.textContentType ?? nil
        let isSecure = proxy.isSecureTextEntry ?? false

        let isNumericOnly = [
            UIKeyboardType.numberPad,
            .phonePad,
            .decimalPad,
            .asciiCapableNumberPad,
        ].contains(keyboardType)
        let isCredential = isSecure || [
            UITextContentType.password,
            .newPassword,
            .oneTimeCode,
        ].contains(contentType)
        let isAddressLike = [UIKeyboardType.emailAddress, .URL].contains(keyboardType)
            || [UITextContentType.emailAddress, .URL, .username].contains(contentType)

        prefersNumberPage = isNumericOnly || keyboardType == .numbersAndPunctuation
        allowsPredictions = isNumericOnly == false && isCredential == false
        allowsAutocorrection = allowsPredictions
            && isAddressLike == false
            && proxy.autocorrectionType != .no
        autocapitalization = proxy.autocapitalizationType ?? .sentences
    }
}
