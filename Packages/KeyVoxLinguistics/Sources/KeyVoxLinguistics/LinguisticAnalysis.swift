import Foundation

public struct LinguisticAnalysis: Sendable {
    public let tokens: [LinguisticToken]
    /// Supported requested features for the resolved language; unknown support is omitted.
    public let availableFeatures: LinguisticFeatures

    public init(tokens: [LinguisticToken], availableFeatures: LinguisticFeatures) {
        self.tokens = tokens
        self.availableFeatures = availableFeatures
    }

    public func token(atUTF16Offset offset: Int) -> LinguisticToken? {
        tokens.first { NSLocationInRange(offset, $0.range) }
    }
}
