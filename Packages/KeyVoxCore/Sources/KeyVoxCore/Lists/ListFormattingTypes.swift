import Foundation

public enum ListRenderMode: Equatable {
    case multiline
    case singleLineInline
}

public struct DetectedListItem {
    public let spokenIndex: Int
    public let content: String

    public init(spokenIndex: Int, content: String) {
        self.spokenIndex = spokenIndex
        self.content = content
    }
}

public struct DetectedList {
    public let leadingText: String
    public let items: [DetectedListItem]
    public let trailingText: String

    public init(leadingText: String, items: [DetectedListItem], trailingText: String) {
        self.leadingText = leadingText
        self.items = items
        self.trailingText = trailingText
    }
}
