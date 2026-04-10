import Foundation

nonisolated struct AppVersion: Codable, Comparable, Equatable, Hashable {
    let rawValue: String

    private let components: [Int]

    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let rawComponents = trimmed.split(separator: ".")
        let parsedComponents = rawComponents.compactMap { Int($0) }

        guard rawComponents.isEmpty == false else { return nil }
        guard parsedComponents.count == rawComponents.count else { return nil }

        self.rawValue = trimmed
        self.components = parsedComponents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)

        guard let version = AppVersion(rawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .rawValue,
                in: container,
                debugDescription: "Invalid app version string: \(rawValue)"
            )
        }

        self = version
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let lhsComponent = index < lhs.components.count ? lhs.components[index] : 0
            let rhsComponent = index < rhs.components.count ? rhs.components[index] : 0

            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }

        return false
    }
}
