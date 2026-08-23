public protocol VoiceActivityAnalyzing: Sendable {
    func analyze(
        audioFrames: [Float],
        configuration: VoiceActivityConfiguration
    ) async -> VoiceActivityAnalysis?
}
