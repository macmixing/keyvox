import Foundation

extension DictationModelID {
    var approximateDownloadSizeText: String {
        switch self {
        case .whisperBase:
            return "~190 MB"
        case .parakeetTdtV3:
            return "~335 MB"
        }
    }
}
