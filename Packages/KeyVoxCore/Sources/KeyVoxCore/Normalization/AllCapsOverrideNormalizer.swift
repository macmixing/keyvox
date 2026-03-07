import Foundation

public struct AllCapsOverrideNormalizer {
    public init() {}

    public func normalize(in text: String, isEnabled: Bool) -> String {
        guard isEnabled else { return text }
        return text.uppercased()
    }
}
