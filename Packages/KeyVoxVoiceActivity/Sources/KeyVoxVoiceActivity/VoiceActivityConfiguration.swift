public struct VoiceActivityConfiguration: Equatable, Sendable {
    public let threshold: Float
    public let minimumSpeechDurationMilliseconds: Int32
    public let minimumSilenceDurationMilliseconds: Int32
    public let speechPaddingMilliseconds: Int32

    public init(
        threshold: Float,
        minimumSpeechDurationMilliseconds: Int32,
        minimumSilenceDurationMilliseconds: Int32,
        speechPaddingMilliseconds: Int32
    ) {
        self.threshold = threshold
        self.minimumSpeechDurationMilliseconds = minimumSpeechDurationMilliseconds
        self.minimumSilenceDurationMilliseconds = minimumSilenceDurationMilliseconds
        self.speechPaddingMilliseconds = speechPaddingMilliseconds
    }

    public static let standard = VoiceActivityConfiguration(
        threshold: 0.5,
        minimumSpeechDurationMilliseconds: 100,
        minimumSilenceDurationMilliseconds: 100,
        speechPaddingMilliseconds: 30
    )
}
