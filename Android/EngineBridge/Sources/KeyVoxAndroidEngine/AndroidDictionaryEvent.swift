import Foundation
import CAndroidEngine
import KeyVoxCore

struct AndroidDictionaryEvent: Encodable {
    enum Operation: String, Encodable {
        case snapshot, add, update, delete, clearWarnings
    }

    let request: Int64
    let operation: Operation
    let available: Bool
    let success: Bool
    let entries: [DictionaryEntry]
    let loadWarningMessage: String?
    let saveErrorMessage: String?
    let errorMessage: String?

    @MainActor
    func send() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        data.withUnsafeBytes { bytes in
            keyvox_dictionary_event(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                Int32(data.count)
            )
        }
    }
}
