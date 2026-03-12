import SwiftUI

struct AppActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    let minWidth: CGFloat
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Kanit Medium", size: 14))
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .frame(minWidth: minWidth)
                .background(backgroundColor)
                .overlay {
                    if style == .secondary {
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
                .clipShape(Capsule())
                .shadow(color: shadowColor, radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? .black : .white.opacity(0.3)
        case .secondary:
            return isEnabled ? .white.opacity(0.9) : .white.opacity(0.3)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? .yellow : Color.white.opacity(0.05)
        case .secondary:
            return Color.white.opacity(isEnabled ? 0.08 : 0.05)
        }
    }

    private var shadowColor: Color {
        guard style == .primary, isEnabled else { return .clear }
        return .yellow.opacity(0.3)
    }
}
