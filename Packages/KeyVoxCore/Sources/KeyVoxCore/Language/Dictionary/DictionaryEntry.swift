import Foundation

public struct DictionaryEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public var phrase: String

    public init(id: UUID = UUID(), phrase: String) {
        self.id = id
        self.phrase = phrase
    }
}
