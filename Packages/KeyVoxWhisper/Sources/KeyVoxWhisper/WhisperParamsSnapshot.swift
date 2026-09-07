import Foundation
import KeyVoxSpeechRuntime

/// Owns the strings managed by WhisperParams for the lifetime of one request.
/// Other pointer fields, including callback data, retain their caller-owned contract.
final class WhisperParamsSnapshot: @unchecked Sendable {
    let raw: whisper_full_params
    private let language: UnsafeMutablePointer<CChar>?
    private let initialPrompt: UnsafeMutablePointer<CChar>?

    init(raw: whisper_full_params) {
        language = Self.copy(raw.language)
        initialPrompt = Self.copy(raw.initial_prompt)
        var owned = raw
        owned.language = language.map { UnsafePointer($0) }
        owned.initial_prompt = initialPrompt.map { UnsafePointer($0) }
        self.raw = owned
    }

    deinit {
        language?.deallocate()
        initialPrompt?.deallocate()
    }

    private static func copy(_ source: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
        guard let source else { return nil }
        let count = Int(strlen(source)) + 1
        let destination = UnsafeMutablePointer<CChar>.allocate(capacity: count)
        destination.initialize(from: source, count: count)
        return destination
    }
}
