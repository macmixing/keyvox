import CoreGraphics

enum MacVibesIntroScene: Int, CaseIterable, Equatable, Hashable {
    case a
    case b
    case c

    static let preferredWindowWidth: CGFloat = 500

    var next: MacVibesIntroScene? {
        switch self {
        case .a:
            return .b
        case .b:
            return .c
        case .c:
            return nil
        }
    }

    var preferredWindowSize: CGSize {
        switch self {
        case .a:
            return CGSize(width: Self.preferredWindowWidth, height: 608)
        case .b:
            return CGSize(width: Self.preferredWindowWidth, height: 584)
        case .c:
            return CGSize(width: Self.preferredWindowWidth, height: 660)
        }
    }
}
