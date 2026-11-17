import Foundation

extension DictationModelID {
    var approximateDownloadSizeText: String {
        switch self {
        case .whisperBase:
            return ApproximateDownloadSize.whisperBase
        case .parakeetTdtV3:
            return ApproximateDownloadSize.parakeet
        }
    }
}
