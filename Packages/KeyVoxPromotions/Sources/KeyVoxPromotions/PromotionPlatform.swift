public enum PromotionPlatform: String, Codable, CaseIterable, Sendable {
    case iOS = "ios"
    case macOS = "macos"
}

public struct PromotionTarget: Codable, Equatable, Sendable {
    public let platform: PromotionPlatform
    public let minimumAppVersion: String?

    public init(platform: PromotionPlatform, minimumAppVersion: String? = nil) {
        self.platform = platform
        self.minimumAppVersion = minimumAppVersion
    }
}
