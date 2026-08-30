import SwiftUI

struct AppPageIndicator: View {
    enum NavigationDirection {
        case previous
        case next
    }

    let pageCount: Int
    let selectedIndex: Int
    var onNavigate: ((NavigationDirection) -> Void)?

    init(
        pageCount: Int,
        selectedIndex: Int,
        onNavigate: ((NavigationDirection) -> Void)? = nil
    ) {
        self.pageCount = pageCount
        self.selectedIndex = selectedIndex
        self.onNavigate = onNavigate
    }

    var body: some View {
        if let onNavigate {
            indicators
                .frame(maxWidth: .infinity)
                .overlay {
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        let direction: NavigationDirection = value.location.x < geometry.size.width / 2
                                            ? .previous
                                            : .next
                                        onNavigate(direction)
                                    }
                            )
                    }
                }
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        onNavigate(.next)
                    case .decrement:
                        onNavigate(.previous)
                    @unknown default:
                        break
                    }
                }
        } else {
            indicators
        }
    }

    private var indicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == selectedIndex ? Color.yellow : Color.white.opacity(0.24))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedIndex + 1) of \(pageCount)")
    }
}
