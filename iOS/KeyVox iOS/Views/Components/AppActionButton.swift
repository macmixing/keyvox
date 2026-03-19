import SwiftUI

struct AppActionButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    enum Size {
        case regular
        case compact
    }

    let title: String
    var systemImage: String? = nil
    var systemImageColor: Color? = nil
    var systemImageWeight: Font.Weight = .regular
    let style: Style
    var minWidth: CGFloat? = nil
    var width: CGFloat? = nil
    var fillsWidth: Bool = false
    var size: Size = .regular
    var fontSize: CGFloat = 14
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(
                    minWidth: fillsWidth ? nil : (width ?? minWidth),
                    idealWidth: fillsWidth ? nil : width,
                    maxWidth: fillsWidth ? .infinity : width,
                    minHeight: minHeight,
                    maxHeight: maxHeight
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

    @ViewBuilder
    private var buttonLabel: some View {
        if let systemImage {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: fontSize, weight: systemImageWeight))
                    .foregroundStyle(systemImageColor ?? foregroundColor)

                Text(title)
                    .font(.appFont(fontSize))
                    .foregroundStyle(foregroundColor)
            }
        } else {
            Text(title)
                .font(.appFont(fontSize))
                .foregroundStyle(foregroundColor)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular:
            return 28
        case .compact:
            return 18
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular:
            return 11
        case .compact:
            return 8
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .regular:
            return 54
        case .compact:
            return 36
        }
    }

    private var maxHeight: CGFloat {
        switch size {
        case .regular:
            return 64
        case .compact:
            return 44
        }
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
