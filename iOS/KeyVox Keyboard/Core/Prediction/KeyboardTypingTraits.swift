import UIKit

/// What the letter keyboard may do in the focused text field: what the field's text traits
/// allow, narrowed by the user's keyboard settings. A feature the field turns off stays off
/// whatever the settings say.
struct KeyboardTypingTraits: Equatable {
    /// The field expects digits first, or the user opens the keyboard on 123, so the keyboard
    /// opens on the number page and stays there until ABC is tapped.
    let prefersNumberPage: Bool
    /// The field allows predictions, so the engine runs for autocorrection and suggestions.
    let allowsPredictions: Bool
    /// Suggestions are shown in the suggestion bar.
    let showsSuggestions: Bool
    let allowsAutocorrection: Bool
    let autocapitalization: UITextAutocapitalizationType
    /// A quick second tap on shift locks caps.
    let allowsCapsLock: Bool
    /// Two spaces after a word type a period and a space.
    let allowsPeriodShortcut: Bool

    /// A field that allows every typing feature, used until the focused field is read.
    static let standard = KeyboardTypingTraits(
        prefersNumberPage: false,
        allowsPredictions: true,
        showsSuggestions: true,
        allowsAutocorrection: true,
        autocapitalization: .sentences,
        allowsCapsLock: true,
        allowsPeriodShortcut: true
    )

    private init(
        prefersNumberPage: Bool,
        allowsPredictions: Bool,
        showsSuggestions: Bool,
        allowsAutocorrection: Bool,
        autocapitalization: UITextAutocapitalizationType,
        allowsCapsLock: Bool,
        allowsPeriodShortcut: Bool
    ) {
        self.prefersNumberPage = prefersNumberPage
        self.allowsPredictions = allowsPredictions
        self.showsSuggestions = showsSuggestions
        self.allowsAutocorrection = allowsAutocorrection
        self.autocapitalization = autocapitalization
        self.allowsCapsLock = allowsCapsLock
        self.allowsPeriodShortcut = allowsPeriodShortcut
    }

    init(proxy: UITextDocumentProxy, settings: KeyboardAppSettingsStore) {
        let keyboardType = proxy.keyboardType ?? .default
        let contentType = proxy.textContentType ?? nil
        let isSecure = proxy.isSecureTextEntry ?? false

        let isNumericOnly = [
            UIKeyboardType.numberPad,
            .phonePad,
            .decimalPad,
            .asciiCapableNumberPad,
        ].contains(keyboardType)
        // A one-time-code label alone keeps predictions, as on Apple's keyboard; a code field
        // that asks for a number pad turns them off as numeric-only.
        let isCredential = isSecure || [
            UITextContentType.password,
            .newPassword,
        ].contains(contentType)
        let isAddressLike = [UIKeyboardType.emailAddress, .URL].contains(keyboardType)
            || [UITextContentType.emailAddress, .URL, .username].contains(contentType)

        prefersNumberPage = isNumericOnly
            || keyboardType == .numbersAndPunctuation
            || settings.opensOnNumberPage
        allowsPredictions = isNumericOnly == false && isCredential == false
        showsSuggestions = allowsPredictions && settings.isPredictiveTextEnabled
        allowsAutocorrection = allowsPredictions
            && isAddressLike == false
            && proxy.autocorrectionType != .no
            && settings.isAutoCorrectionEnabled
        autocapitalization = settings.isAutoCapitalizationEnabled
            ? proxy.autocapitalizationType ?? .sentences
            : .none
        allowsCapsLock = settings.isShiftCapsLockEnabled
        allowsPeriodShortcut = settings.isPeriodShortcutEnabled
    }
}
