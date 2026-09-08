import Foundation
import CAndroidEngine

struct EngineEvent: Encodable {
    enum Kind: String, Encodable { case configured, modelDownloading, modelReady, modelFailed, result, failed, cancelled }
    let kind: Kind
    var request: Int64? = nil
    var text: String? = nil
    var noSpeech: Bool? = nil
    var modelReady: Bool? = nil

    @MainActor func send() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        String(decoding: data, as: UTF8.self).withCString { keyvox_engine_event($0) }
    }
}
