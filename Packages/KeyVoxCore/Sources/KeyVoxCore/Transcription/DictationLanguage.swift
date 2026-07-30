public struct DictationLanguage: RawRepresentable, Hashable, Identifiable, Sendable {
    public static let automatic = DictationLanguage(rawValue: "auto")

    public let rawValue: String

    public var id: String { rawValue }

    public var isAutomatic: Bool {
        self == .automatic
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
