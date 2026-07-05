import Foundation

public struct StyleRewriteInputVariant: Codable, Equatable, Sendable {
    public let paragraphsEnabled: Bool
    public let listsEnabled: Bool
    public let text: String

    public init(
        paragraphsEnabled: Bool,
        listsEnabled: Bool,
        text: String
    ) {
        self.paragraphsEnabled = paragraphsEnabled
        self.listsEnabled = listsEnabled
        self.text = text
    }
}

public enum StyleRewriteInputVariantSelection {
    public static func baseText(
        for style: StyleRewriteStyle,
        baseText: String,
        deterministicVariants: [StyleRewriteInputVariant]
    ) -> String {
        guard style.usesModelRewrite else { return baseText }

        for variant in deterministicVariants where !variant.listsEnabled {
            let repaired = OutputRepair.repairModelOutput(
                original: variant.text,
                rewritten: variant.text
            )
            guard repaired != variant.text,
                  repaired != baseText else {
                continue
            }
            return variant.text
        }

        return baseText
    }
}
