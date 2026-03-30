import Foundation
import KeyVoxCore

typealias DictationService =
    DictationTranscriptionProviding &
    DictationTranscriptionControlling &
    DictationModelLifecycleProviding
