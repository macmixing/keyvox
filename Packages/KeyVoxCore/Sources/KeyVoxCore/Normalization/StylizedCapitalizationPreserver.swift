import Foundation

struct StylizedCapitalizationPreserver {
    private static let surroundingPunctuation = CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?")

    func preservesExistingCasing(in token: String) -> Bool {
        let stripped = token.trimmingCharacters(in: Self.surroundingPunctuation)
        let scalars = Array(stripped.unicodeScalars)
        guard let firstScalar = scalars.first,
              firstScalar.properties.isLowercase,
              scalars.count > 1 else {
            return false
        }

        return scalars.dropFirst().contains(where: { $0.properties.isUppercase })
    }
}
