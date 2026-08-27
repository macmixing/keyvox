import Foundation

struct PromotionVersion: Comparable, Sendable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let parsedComponents = rawValue.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parsedComponents.isEmpty == false,
              parsedComponents.allSatisfy({ $0.isEmpty == false && $0.allSatisfy(\.isNumber) }),
              parsedComponents.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        components = parsedComponents.map { Int($0)! }
    }

    static func < (lhs: PromotionVersion, rhs: PromotionVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let lhsComponent = index < lhs.components.count ? lhs.components[index] : 0
            let rhsComponent = index < rhs.components.count ? rhs.components[index] : 0
            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }
        return false
    }
}
