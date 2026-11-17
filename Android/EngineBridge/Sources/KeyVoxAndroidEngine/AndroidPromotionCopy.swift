import KeyVoxPromotions

/// The campaign wording Java renders, already chosen for the app's language by the shared promotions package.
struct AndroidPromotionCopy: Encodable {
    let title: String
    let message: String
    let buttonTitle: String?
    let sharingTitle: String?

    init(_ copy: PromotionCopy) {
        title = copy.title
        message = copy.message
        buttonTitle = copy.buttonTitle
        sharingTitle = copy.sharingTitle
    }
}
