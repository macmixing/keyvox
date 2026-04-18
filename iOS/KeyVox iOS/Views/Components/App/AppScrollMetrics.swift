import SwiftUI

struct AppScrollMetrics: Equatable {
    static let zero = AppScrollMetrics(
        contentHeight: 0,
        visibleHeight: 0,
        visibleMinY: 0,
        maximumVisibleMinY: 0
    )

    let contentHeight: CGFloat
    let visibleHeight: CGFloat
    let visibleMinY: CGFloat
    let maximumVisibleMinY: CGFloat
}
