import Foundation

public struct PromotionManifest: Codable, Equatable, Sendable {
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let selection: PromotionSelectionPolicy
    public let campaigns: [PromotionCampaign]

    public init(
        schemaVersion: Int = PromotionManifest.supportedSchemaVersion,
        selection: PromotionSelectionPolicy,
        campaigns: [PromotionCampaign]
    ) {
        self.schemaVersion = schemaVersion
        self.selection = selection
        self.campaigns = campaigns
    }
}

public struct PromotionSelectionPolicy: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable {
        case `static`
        case rotating
    }

    public let mode: Mode
    public let intervalHours: Double?

    public init(mode: Mode, intervalHours: Double? = nil) {
        self.mode = mode
        self.intervalHours = intervalHours
    }

    var interval: TimeInterval? {
        intervalHours.map { $0 * 60 * 60 }
    }
}
