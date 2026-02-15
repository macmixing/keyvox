import Foundation

public struct Segment: Sendable {
    public let startTime: Int
    public let endTime: Int
    public let text: String
    public let noSpeechProbability: Float

    public init(
        startTime: Int,
        endTime: Int,
        text: String,
        noSpeechProbability: Float = 0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.noSpeechProbability = noSpeechProbability
    }
}
