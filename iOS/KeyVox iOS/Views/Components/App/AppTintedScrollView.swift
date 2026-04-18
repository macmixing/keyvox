import SwiftUI

struct AppTintedScrollView<Content: View>: View {
    let content: Content
    let contentPadding: CGFloat
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat
    let indicatorTint: Color

    @State private var scrollMetrics = AppScrollMetrics.zero

    init(
        contentPadding: CGFloat,
        minimumHeight: CGFloat,
        maximumHeight: CGFloat,
        indicatorTint: Color = .yellow,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.contentPadding = contentPadding
        self.minimumHeight = minimumHeight
        self.maximumHeight = maximumHeight
        self.indicatorTint = indicatorTint
    }

    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        .contentMargins(.all, contentPadding, for: .scrollContent)
        .frame(
            minHeight: minimumHeight,
            maxHeight: maximumHeight,
            alignment: .top
        )
        .onScrollGeometryChange(for: AppScrollMetrics.self) { geometry in
            let visibleRect = geometry.visibleRect
            let maximumVisibleMinY = max(0, geometry.contentSize.height - visibleRect.height)

            return AppScrollMetrics(
                contentHeight: geometry.contentSize.height,
                visibleHeight: visibleRect.height,
                visibleMinY: min(max(visibleRect.minY, 0), maximumVisibleMinY),
                maximumVisibleMinY: maximumVisibleMinY
            )
        } action: { _, newMetrics in
            scrollMetrics = newMetrics
        }
        .overlay(alignment: .topTrailing) {
            AppTintedScrollIndicator(metrics: scrollMetrics, tint: indicatorTint)
        }
    }
}
