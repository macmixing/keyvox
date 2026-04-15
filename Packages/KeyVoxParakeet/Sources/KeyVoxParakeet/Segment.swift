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
    static let minimumRejectedNoSpeechProbability: Float = 0.50

    public static func isLikelyNoSpeech(
        result: ParakeetTranscriptionResult,
        audioFrameCount: Int
    ) -> Bool {
        let nonEmptySegments = result.segments.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !nonEmptySegments.isEmpty else { return true }

        let durationSeconds = utteranceDurationSeconds(
            for: nonEmptySegments,
            fallbackAudioFrameCount: audioFrameCount
        )
        guard durationSeconds <= shortUtteranceMaximumDurationSeconds else { return false }

        let segmentNoSpeechProbabilities = nonEmptySegments.compactMap(\.noSpeechProbability)
        if !segmentNoSpeechProbabilities.isEmpty {
            let averageNoSpeechProbability =
                segmentNoSpeechProbabilities.reduce(0, +) / Float(segmentNoSpeechProbabilities.count)
            if averageNoSpeechProbability >= minimumRejectedNoSpeechProbability {
                return true
            }
        }

        let segmentConfidences = nonEmptySegments.compactMap(\.confidence)
        guard !segmentConfidences.isEmpty else { return false }

        let wordCount = wordCount(for: nonEmptySegments)
        guard wordCount == 1 else { return false }

        let averageConfidence = segmentConfidences.reduce(0, +) / Float(segmentConfidences.count)
        return averageConfidence < minimumConfirmedConfidenceForSingleWord(
            utteranceDurationSeconds: durationSeconds
        )
    }

    public static func droppingLikelyNoSpeechTrailingSegments(
        from result: ParakeetTranscriptionResult
    ) -> ParakeetTranscriptionResult {
        var filteredSegments = result.segments

        while filteredSegments.count > 1 {
            guard let trailingSegment = filteredSegments.last else { break }
            let trailingText = trailingSegment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trailingText.isEmpty else {
                filteredSegments.removeLast()
                continue
            }

            let trailingAudioFrameCount = audioFrameCount(for: trailingSegment)
            let trailingResult = ParakeetTranscriptionResult(
                segments: [trailingSegment],
                detectedLanguageCode: result.detectedLanguageCode,
                detectedLanguageName: result.detectedLanguageName
            )

            guard isLikelyNoSpeech(
                result: trailingResult,
                audioFrameCount: trailingAudioFrameCount
            ) else {
                break
            }

            filteredSegments.removeLast()
        }

        return ParakeetTranscriptionResult(
            segments: filteredSegments,
            detectedLanguageCode: result.detectedLanguageCode,
            detectedLanguageName: result.detectedLanguageName
        )
    }

    static func utteranceDurationSeconds(
        for nonEmptySegments: [ParakeetSegment],
        fallbackAudioFrameCount: Int
    ) -> Double {
        guard let firstSegment = nonEmptySegments.first,
              let lastSegment = nonEmptySegments.last else {
            return Double(fallbackAudioFrameCount) / sampleRate
        }

        let utteranceMilliseconds = max(0, lastSegment.endTime - firstSegment.startTime)
        guard utteranceMilliseconds > 0 else {
            return Double(fallbackAudioFrameCount) / sampleRate
        }

        return Double(utteranceMilliseconds) / 1_000.0
    }

    static func audioFrameCount(for segment: ParakeetSegment) -> Int {
        let durationMilliseconds = max(0, segment.endTime - segment.startTime)
        return max(1, Int((Double(durationMilliseconds) / 1_000.0) * sampleRate))
    }

    static func wordCount(for segments: [ParakeetSegment]) -> Int {
        segments
            .map(\.text)
            .joined(separator: " ")
            .split { $0.isWhitespace }
            .count
    }

    static func minimumConfirmedConfidenceForSingleWord(
        utteranceDurationSeconds: Double
    ) -> Float {
        let clampedDuration = min(max(utteranceDurationSeconds, 0), shortUtteranceMaximumDurationSeconds)
        let normalizedDuration = Float(clampedDuration / shortUtteranceMaximumDurationSeconds)
        let shortestUtteranceThreshold: Float = 0.64
        let longestUtteranceThreshold: Float = 0.60

        return shortestUtteranceThreshold -
            ((shortestUtteranceThreshold - longestUtteranceThreshold) * normalizedDuration)
    }
}
