import SwiftUI

/// Visible scroll geometry used to render an app-owned scroll indicator.
struct AppScrollMetrics: Equatable {
    /// Full height of the scrollable content.
    let contentHeight: CGFloat
    /// Height of the currently visible content rect.
    let visibleHeight: CGFloat
    /// Current top edge of the visible content rect in content coordinates.
    let visibleMinY: CGFloat
    /// Largest top-edge value the visible content rect can reach at the bottom.
    let maximumVisibleMinY: CGFloat

    static let zero = AppScrollMetrics(
        contentHeight: 0,
        visibleHeight: 0,
        visibleMinY: 0,
        maximumVisibleMinY: 0
    )

    var isAtTop: Bool {
        visibleMinY <= 0
    }

    var isAtBottom: Bool {
        visibleMinY >= maximumVisibleMinY
    }

    var scrollProgress: CGFloat {
        guard maximumVisibleMinY > 0 else { return 0 }
        return min(max(visibleMinY / maximumVisibleMinY, 0), 1)
    }
}
