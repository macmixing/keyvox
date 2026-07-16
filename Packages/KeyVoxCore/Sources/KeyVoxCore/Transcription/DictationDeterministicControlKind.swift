public enum DictationDeterministicControlKind: Sendable {
    case paragraphs
    case lists

    public var debugLabel: String {
        switch self {
        case .paragraphs:
            return "paragraphs"
        case .lists:
            return "lists"
        }
    }
}
