import SwiftUI

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case dictionary = "Dictionary"
    case style = "Style"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dictionary: return "text.book.closed.fill"
        case .style: return "scribble.variable"
        case .settings: return "gearshape.fill"
        }
    }
}


// MARK: - Animated Wave Header
struct AnimatedWaveHeader<Trailing: View>: View {
    private let trailing: Trailing

    init() where Trailing == EmptyView {
        self.trailing = EmptyView()
    }

    init(@ViewBuilder trailing: () -> Trailing) {
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            LogoBarView()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("KeyVox")
                    .font(.appFont(24))
                    .foregroundColor(.white)
                Text("Free Your Voice")
                    .font(.appFont(10))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
            }

            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Settings Card
struct SettingsCard<Content: View>: View {
    let fillColor: Color
    let strokeColor: Color
    let content: Content
    
    init(
        fillColor: Color = MacAppTheme.cardFill,
        strokeColor: Color = MacAppTheme.cardStroke,
        @ViewBuilder content: () -> Content
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(fillColor)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Settings Row
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accessory: Accessory
    
    init(icon: String, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.appFont(20))
                    .foregroundColor(MacAppTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(17))
                
                Text(subtitle)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            
            accessory
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct DeveloperLinkCard: View {
    private static let promoCardFill = Color.yellow.opacity(0.14)
    private static let promoCardStroke = Color.yellow.opacity(0.32)

    @State private var showsAnimatedGlow = false

    enum Icon {
        case asset(String)
        case assetTemplate(String)
        case appBundleIcon
        case systemImage(String)
    }

    let icon: Icon
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isPromoted: Bool
    let action: () -> Void

    private var appIconGlowLayer: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.yellow)
            .frame(width: 44, height: 44)
            .blur(radius: 8)
            .opacity(showsAnimatedGlow ? 0.76 : 0.36)
            .compositingGroup()
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: showsAnimatedGlow)
    }

    var body: some View {
        SettingsCard(
            fillColor: isPromoted ? Self.promoCardFill : MacAppTheme.cardFill,
            strokeColor: isPromoted ? Self.promoCardStroke : MacAppTheme.cardStroke
        ) {
            HStack(spacing: 16) {
                iconView

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appFont(16))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(subtitle)
                        .font(.appFont(13))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AppActionButton(
                    title: buttonTitle,
                    style: isPromoted ? .primary : .secondary,
                    minWidth: 96
                ) {
                    action()
                }
            }
        }
        .onAppear {
            guard case .appBundleIcon = icon, showsAnimatedGlow == false else { return }
            showsAnimatedGlow = true
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .cornerRadius(12)
        case .assetTemplate(let name):
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)
                Image(name)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.yellow.opacity(0.85))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
            }
        case .appBundleIcon:
            ZStack {
                appIconGlowLayer

                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.24)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.9), lineWidth: 0.3)
                    )
            }
        case .systemImage(let name):
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)
                Image(systemName: name)
                    .font(.appFont(20))
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(tab.rawValue)
                    .font(.appFont(15))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? MacAppTheme.sidebarSelectionFill : (isHovered ? MacAppTheme.sidebarHoverFill : Color.clear))
            )
        }
        .buttonStyle(DepressedButtonStyle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title.uppercased())
            .font(.appFont(9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Tip Item
struct TipItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.appFont(10))
                .foregroundColor(.yellow)
            Text(text)
                .font(.appFont(11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MacAppTheme.tipFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Button Styles
struct DepressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
