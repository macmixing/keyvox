/// Suggestions computed for one prediction request.
public struct PredictionResult: Sendable, Equatable {
    public let request: PredictionRequest
    public let bar: SuggestionBar
    /// What space should insert in place of the current word, already in the typed case.
    public let autocorrection: String?
}
