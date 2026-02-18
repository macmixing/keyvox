import Foundation

enum ListRenderMode: Equatable {
    case multiline
    case singleLineInline
}

struct DetectedListItem {
    let spokenIndex: Int
    let content: String
}

struct DetectedList {
    let leadingText: String
    let items: [DetectedListItem]
    let trailingText: String
}
