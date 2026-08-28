import Foundation

public struct PromotionIcon: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case systemImage
        case appBundleIcon
        case asset
    }

    public let kind: Kind
    public let name: String?

    public init(kind: Kind, name: String? = nil) {
        self.kind = kind
        self.name = name
    }
}

public struct PromotionAction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case web
    }

    public let kind: Kind
    public let url: URL

    public init(kind: Kind = .web, url: URL) {
        self.kind = kind
        self.url = url
    }
}

public struct PromotionSharing: Codable, Equatable, Sendable {
    public let url: URL
    public let title: String?

    public init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title
    }
}
