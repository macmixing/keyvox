import Foundation

struct DictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var phrase: String

    init(id: UUID = UUID(), phrase: String) {
        self.id = id
        self.phrase = phrase
    }
}
