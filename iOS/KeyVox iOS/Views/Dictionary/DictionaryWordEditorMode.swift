import Foundation
import KeyVoxCore

enum DictionaryWordEditorMode: Identifiable {
    case add
    case edit(DictionaryEntry)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let entry):
            return "edit-\(entry.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .add:
            return "Add Dictionary Word"
        case .edit:
            return "Edit Dictionary Word"
        }
    }

    var actionTitle: String {
        switch self {
        case .add:
            return "Add Word"
        case .edit:
            return "Save Word"
        }
    }

    var initialPhrase: String {
        switch self {
        case .add:
            return ""
        case .edit(let entry):
            return entry.phrase
        }
    }
}
