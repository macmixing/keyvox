import SwiftUI

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case model = "AI Engine"
    case more = "More"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .audio: return "mic.fill"
        case .model: return "cpu"
        case .more: return "star.fill"
        }
    }
}


// MARK: - Animated Wave Header
struct AnimatedWaveHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            KeyVoxLogo()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("KeyVox")
                    .font(.custom("Kanit Medium", size: 24))
                    .foregroundColor(.indigo)
                Text("Local.  Private. Fast.")
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
        }
    }
}

// MARK: - Settings Card
struct SettingsCard<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
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
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.custom("Kanit Medium", size: 20))
                    .foregroundColor(.indigo)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Kanit Medium", size: 17))
                
                Text(subtitle)
                    .font(.custom("Kanit Medium", size: 12))
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
                    .font(.custom("Kanit Medium", size: 15))
                
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
                    .fill(isSelected ? Color.indigo.opacity(0.3) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
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
            .font(.custom("Kanit Medium", size: 9))
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
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.yellow)
            Text(text)
                .font(.custom("Kanit Medium", size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
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
