import Foundation

/// The wording a host shows for a campaign in one language.
public struct PromotionCopy: Equatable, Sendable {
    public let title: String
    public let message: String
    public let buttonTitle: String?
    public let sharingTitle: String?
}

public extension PromotionCampaign {
    /// Returns the campaign's wording for a language code such as `de` or `es-419`, falling back to the base wording.
    func copy(forLanguage languageCode: String?) -> PromotionCopy {
        let base = PromotionCopy(
            title: title,
            message: message,
            buttonTitle: buttonTitle,
            sharingTitle: sharing?.title
        )
        guard let languageCode, let localized = localizedCopy(forLanguage: languageCode) else {
            return base
        }

        return PromotionCopy(
            title: localized.title,
            message: localized.message,
            buttonTitle: buttonTitle == nil ? nil : localized.buttonTitle ?? buttonTitle,
            sharingTitle: sharing?.title == nil ? nil : localized.sharingTitle ?? sharing?.title
        )
    }

    private func localizedCopy(forLanguage languageCode: String) -> PromotionLocalizedCopy? {
        guard let localizations else { return nil }
        if let exact = localizations[languageCode] {
            return exact
        }

        let baseLanguage = languageCode.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
        guard let baseLanguage, baseLanguage != languageCode else { return nil }
        return localizations[baseLanguage]
    }
}
