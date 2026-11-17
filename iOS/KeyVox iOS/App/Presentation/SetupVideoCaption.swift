import Foundation

/// The setup videos were made with English words in the picture, so a translated caption
/// is shown under them whenever the app is showing another language.
enum SetupVideoCaption {
    static var isShown: Bool {
        guard let shownLanguage = Bundle.main.preferredLocalizations.first,
              let videoLanguage = Bundle.main.developmentLocalization else {
            return false
        }
        return Locale(identifier: shownLanguage).language.languageCode
            != Locale(identifier: videoLanguage).language.languageCode
    }
}
