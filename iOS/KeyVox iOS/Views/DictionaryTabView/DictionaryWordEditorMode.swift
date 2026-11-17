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
            return String(localized: "Add Word", comment: "Title of the sheet for adding a word to the Dictionary.")
        case .edit:
            return String(localized: "Edit Word", comment: "Title of the sheet for editing a Dictionary entry.")
        }
    }

    var actionTitle: String {
        switch self {
        case .add:
            return String(localized: "Add", comment: "Button in the Dictionary word sheet that adds the typed word.")
        case .edit:
            return String(localized: "Save", comment: "Button in the Dictionary word sheet that saves changes to an entry.")
        }
    }

    var showsDescription: Bool {
        switch self {
        case .add:
            return true
        case .edit:
            return false
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
