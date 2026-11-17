import Foundation

/// One language's wording for a campaign. Hosts that predate this field ignore it and keep showing the base wording.
public struct PromotionLocalizedCopy: Codable, Equatable, Sendable {
    public let title: String
    public let message: String
    public let buttonTitle: String?
    public let sharingTitle: String?

    public init(
        title: String,
        message: String,
        buttonTitle: String? = nil,
        sharingTitle: String? = nil
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.sharingTitle = sharingTitle
    }
}
