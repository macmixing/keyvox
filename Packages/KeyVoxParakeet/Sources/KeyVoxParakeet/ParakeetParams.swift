public final class ParakeetParams: @unchecked Sendable {
    public static var `default`: ParakeetParams {
        ParakeetParams()
    }

    public var languageCode: String?
    public var initialPrompt: String
    public var enableTimestamps: Bool
    public var maxAlternatives: Int

    public init(
        languageCode: String? = nil,
        initialPrompt: String = "",
        enableTimestamps: Bool = false,
        maxAlternatives: Int = 1
    ) {
        self.languageCode = languageCode
        self.initialPrompt = initialPrompt
        self.enableTimestamps = enableTimestamps
        self.maxAlternatives = max(1, maxAlternatives)
    }
}
