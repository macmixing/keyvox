import Foundation

enum TranscriptionStartCommandResult: Equatable {
    case started
    case alreadyInProgress
    case failed(String)
}

enum TranscriptionStopCommandResult: Equatable {
    case completed(String)
    case noSpeech
    case notRecording
    case superseded
    case failed(String)
}
