import Foundation
import KeyVoxPredictiveKeyboard

/// The web endings a web address field's key types and offers when held: Apple's choice for the
/// device's region and languages and the keyboard's typing languages, the one it types in first
/// (`WebEndings`). Use from the main thread.
enum KeyboardWebEndings {
    private static let endings: WebEndings = {
        do {
            return try WebEndings.bundled()
        } catch {
            preconditionFailure("the bundled web endings did not load: \(error)")
        }
    }()

    private static var latest: (key: [String], offer: WebEndings.Offer)?

    /// The offer for the device and the keyboard's languages as they are now, worked out again
    /// when the region, the device's languages, or the typing languages change.
    static var current: WebEndings.Offer {
        let region = Locale.current.region?.identifier
        let preferredLanguages = Locale.preferredLanguages
        let typing = KeyboardTypingLanguage.current
        let others = KeyboardTypingLanguage.selection.identifiers.filter { $0 != typing.identifier }
        let key = [region ?? ""] + preferredLanguages + [typing.identifier] + others
        if let latest, latest.key == key { return latest.offer }
        let languages = [typing] + others.compactMap { try? TypingLanguage.bundled(identifier: $0) }
        guard let offer = endings.offer(region: region, preferredLanguages: preferredLanguages, languages: languages) else {
            preconditionFailure("no web endings for \(typing.identifier)")
        }
        latest = (key, offer)
        return offer
    }
}
