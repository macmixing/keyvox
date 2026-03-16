import SwiftUI

struct iOSAppActionButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let style: Style
    var width: CGFloat? = nil
    var fillsWidth: Bool = false
    var fontSize: CGFloat = 14
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appFont(fontSize))
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .frame(
                    minWidth: fillsWidth ? nil : width,
                    idealWidth: fillsWidth ? nil : width,
                    maxWidth: fillsWidth ? .infinity : width,
                    minHeight: 54,
                    maxHeight: 64
                )
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
        case .destructive:
            return isEnabled ? .white : .white.opacity(0.3)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? .yellow : Color.white.opacity(0.05)
        case .secondary:
            return Color.white.opacity(isEnabled ? 0.08 : 0.05)
        case .destructive:
            return isEnabled ? .red : Color.white.opacity(0.05)
        }
    }

    private var shadowColor: Color {
        guard isEnabled else { return .clear }

        switch style {
        case .primary:
            return .yellow.opacity(0.3)
        case .destructive:
            return .red.opacity(0.3)
        case .secondary:
            return .clear
        }
    }
}
