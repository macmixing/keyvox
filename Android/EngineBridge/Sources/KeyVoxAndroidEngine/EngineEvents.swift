import Foundation
import CAndroidEngine
import KeyVoxPromotions

struct EngineEvent: Encodable {
    enum Kind: String, Encodable {
        case configured, modelDownloading, modelReady, modelFailed, result, failed, cancelled
        case promotionConfigured
    }
    let kind: Kind
    var request: Int64? = nil
    var text: String? = nil
    var noSpeech: Bool? = nil
    var modelReady: Bool? = nil
    var optionalModelAvailable: Bool? = nil
    var audioReadMilliseconds: Double? = nil
    var modelWarmupMilliseconds: Double? = nil
    var inferenceMilliseconds: Double? = nil
    var pipelineMilliseconds: Double? = nil
    var postProcessorPreparationWaitMilliseconds: Double? = nil
    var campaign: PromotionCampaign? = nil

    @MainActor func send() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        String(decoding: data, as: UTF8.self).withCString { keyvox_engine_event($0) }
    }
}
