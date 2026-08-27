import Foundation

public struct PromotionCampaign: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let targets: [PromotionTarget]
    public let icon: PromotionIcon
    public let title: String
    public let message: String
    public let buttonTitle: String?
    public let action: PromotionAction?
    public let sharing: PromotionSharing?
    public let startsAt: Date?
    public let endsAt: Date?

    public init(
        id: String,
        targets: [PromotionTarget],
        icon: PromotionIcon,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: PromotionAction? = nil,
        sharing: PromotionSharing? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil
    ) {
        self.id = id
        self.targets = targets
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
        self.sharing = sharing
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}
