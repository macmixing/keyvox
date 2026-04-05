public struct ParakeetSegment: Sendable, Equatable {
    public let startTime: Int
    public let endTime: Int
    public let text: String
    public let confidence: Float?
    public let noSpeechProbability: Float?

    public init(
        startTime: Int,
        endTime: Int,
        text: String,
        confidence: Float? = nil,
        noSpeechProbability: Float? = nil
    ) {
        precondition(endTime >= startTime, "endTime must be greater than or equal to startTime")
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
        self.noSpeechProbability = noSpeechProbability
    }
}

public struct ParakeetTranscriptionResult: Sendable, Equatable {
    public let segments: [ParakeetSegment]
    public let detectedLanguageCode: String?
    public let detectedLanguageName: String?

    public init(
        segments: [ParakeetSegment],
        detectedLanguageCode: String? = nil,
        detectedLanguageName: String? = nil
    ) {
        self.segments = segments
        self.detectedLanguageCode = detectedLanguageCode
        self.detectedLanguageName = detectedLanguageName
    }
}

public enum ParakeetUtteranceGate {
    static let sampleRate: Double = 16_000
    static let shortUtteranceMaximumDurationSeconds: Double = 1.0
    static let minimumConfirmedConfidence: Float = 0.80

    public static func isLikelyNoSpeech(
        result: ParakeetTranscriptionResult,
        audioFrameCount: Int
    ) -> Bool {
        let nonEmptySegments = result.segments.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !nonEmptySegments.isEmpty else { return true }

        let durationSeconds = Double(audioFrameCount) / sampleRate
        guard durationSeconds <= shortUtteranceMaximumDurationSeconds else { return false }

        let segmentConfidences = nonEmptySegments.compactMap(\.confidence)
        guard !segmentConfidences.isEmpty else { return false }

        let averageConfidence = segmentConfidences.reduce(0, +) / Float(segmentConfidences.count)
        return averageConfidence < minimumConfirmedConfidence
    }
}
