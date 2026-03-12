import SwiftUI

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case dictionary = "Dictionary"
    case more = "More"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .audio: return "mic.fill"
        case .dictionary: return "text.book.closed.fill"
        case .more: return "star.fill"
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
                    .foregroundColor(MacAppTheme.accent)
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
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(MacAppTheme.cardFill)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(MacAppTheme.cardStroke, lineWidth: 1)
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
                    .font(.appFont(12))
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
