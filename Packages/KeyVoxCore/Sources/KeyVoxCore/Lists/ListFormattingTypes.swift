import Foundation

public enum ListRenderMode: Equatable {
    case multiline
    case singleLineInline
}

public struct DetectedListItem {
    let spokenIndex: Int
    let content: String
}

public struct DetectedList {
    let leadingText: String
    let items: [DetectedListItem]
    let trailingText: String
}
