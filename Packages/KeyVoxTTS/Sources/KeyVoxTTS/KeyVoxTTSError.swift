import Foundation

public enum KeyVoxTTSError: LocalizedError, Sendable {
    case invalidAssetLayout(String)
    case missingModel(String)
    case missingAsset(String)
    case invalidAssetData(String)
    case invalidVoice(String)
    case inferenceFailure(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidAssetLayout(message),
             let .missingModel(message),
             let .missingAsset(message),
             let .invalidAssetData(message),
             let .invalidVoice(message),
             let .inferenceFailure(message):
            return message
        }
    }
}
