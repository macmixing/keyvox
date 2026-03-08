import Foundation
import KeyVoxCore

nonisolated struct KeyVoxDictionaryCloudPayload: Codable, Equatable {
    let modifiedAt: Date
    let entries: [DictionaryEntry]
}
