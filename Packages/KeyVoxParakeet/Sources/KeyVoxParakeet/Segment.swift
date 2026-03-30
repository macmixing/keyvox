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
