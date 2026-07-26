import CoreGraphics
import Foundation

public enum PredictionMode: Sendable {
    case correction
    case completion
    case nextWord
}

public struct PredictionKeyGeometry: Sendable {
    public let character: Character
    public let frame: CGRect

    public init(character: Character, frame: CGRect) {
        self.character = character
        self.frame = frame
    }
}

public struct PredictionTouch: Sendable {
    public let location: CGPoint

    public init(location: CGPoint) {
        self.location = location
    }
}

public struct PredictiveSuggestion: Equatable, Sendable {
    public let word: String
    public let nativeScore: Int
    public let nativeType: Int
    public let rankProbability: Double

    public init(
        word: String,
        nativeScore: Int,
        nativeType: Int,
        rankProbability: Double
    ) {
        self.word = word
        self.nativeScore = nativeScore
        self.nativeType = nativeType
        self.rankProbability = rankProbability
    }
}

public struct PredictionResponse: Equatable, Sendable {
    public let suggestions: [PredictiveSuggestion]
    public let automaticCorrectionProbability: Double
    public let typedWordIsValid: Bool

    public init(
        suggestions: [PredictiveSuggestion],
        automaticCorrectionProbability: Double,
        typedWordIsValid: Bool
    ) {
        self.suggestions = suggestions
        self.automaticCorrectionProbability = automaticCorrectionProbability
        self.typedWordIsValid = typedWordIsValid
    }
}

public struct WordLanguageAnalysis: Equatable, Sendable {
    public let wordIsValid: Bool
    public let unigramLogProbability: Double
    public let precedingLogProbability: Double
    public let precedingPairObserved: Bool
    public let precedingTrigramLogProbability: Double
    public let precedingTrigramObserved: Bool

    public init(
        wordIsValid: Bool,
        unigramLogProbability: Double,
        precedingLogProbability: Double,
        precedingPairObserved: Bool,
        precedingTrigramLogProbability: Double = 0,
        precedingTrigramObserved: Bool = false
    ) {
        self.wordIsValid = wordIsValid
        self.unigramLogProbability = unigramLogProbability
        self.precedingLogProbability = precedingLogProbability
        self.precedingPairObserved = precedingPairObserved
        self.precedingTrigramLogProbability = precedingTrigramLogProbability
        self.precedingTrigramObserved = precedingTrigramObserved
    }
}

public enum PredictiveKeyboardError: Error, Equatable {
    case missingArtifact(String)
    case nativeEngineInitializationFailed(String)
    case nativePredictionFailed(String)
    case invalidAccentOverlay
}
