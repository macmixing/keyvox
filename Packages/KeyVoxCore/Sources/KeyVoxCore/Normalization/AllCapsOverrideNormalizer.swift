import Foundation

public struct AllCapsOverrideNormalizer {
    func normalize(in text: String, isEnabled: Bool) -> String {
        guard isEnabled else { return text }
        return text.uppercased()
    }
}
