/// The skin-tone versions of an emoji of two people, such as a handshake or a couple, by the tone
/// each person takes: the first person is the one Unicode names first, on the left. Both in the
/// same tone is the emoji's one-tone version ("🤝🏼"); different tones, the version that carries
/// both ("🫱🏼‍🫲🏿").
public struct EmojiTwoPersonTones: Sendable, Equatable {
    /// How many skin tones each person comes in, lightest first.
    public static let toneCount = 5
    private static let firstModifier: UInt32 = 0x1F3FB

    private let versions: [Pair: String]

    private struct Pair: Hashable, Sendable {
        let first: Int
        let second: Int
    }

    /// The tones of `emoji`, or nil unless it comes in a version for every pair of tones.
    public init?(_ emoji: Emoji) {
        var versions: [Pair: String] = [:]
        for version in emoji.skinToneVariants {
            let tones = version.unicodeScalars.compactMap(Self.tone)
            switch tones.count {
            case 1:
                versions[Pair(first: tones[0], second: tones[0])] = version
            case 2:
                versions[Pair(first: tones[0], second: tones[1])] = version
            default:
                return nil
            }
        }
        guard versions.count == Self.toneCount * Self.toneCount else { return nil }
        self.versions = versions
    }

    /// The version with the first person in tone `first` and the second in tone `second`.
    public func version(first: Int, second: Int) -> String? {
        versions[Pair(first: first, second: second)]
    }

    /// The tones of `version`, first person first, or nil for a version that is not one of these.
    public func tones(of version: String) -> (first: Int, second: Int)? {
        versions.first { $0.value == version }.map { ($0.key.first, $0.key.second) }
    }

    private static func tone(_ scalar: Unicode.Scalar) -> Int? {
        let offset = Int(scalar.value) - Int(firstModifier)
        return (0..<toneCount).contains(offset) ? offset : nil
    }
}
