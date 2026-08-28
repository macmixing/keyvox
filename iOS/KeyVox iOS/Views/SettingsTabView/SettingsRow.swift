import SwiftUI

struct SettingsRow<TrailingContent: View>: View {
    private enum Icon {
        case system(String)
        case asset(String)
    }

    private let icon: Icon?
    let title: String
    let description: String
    let trailingContent: TrailingContent
    
    init(
        icon: String? = nil,
        assetIcon: String? = nil,
        title: String,
        description: String,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.icon = assetIcon.map(Icon.asset) ?? icon.map(Icon.system)
        self.title = title
        self.description = description
        self.trailingContent = trailingContent()
    }
    
    init(
        icon: String? = nil,
        assetIcon: String? = nil,
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) where TrailingContent == AnyView {
        self.icon = assetIcon.map(Icon.asset) ?? icon.map(Icon.system)
        self.title = title
        self.description = description
        self.trailingContent = AnyView(
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                if let icon {
                    iconView(icon)
                }
                
                Text(title)
                    .font(.appFont(18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                trailingContent
            }
            
            Text(description)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func iconView(_ icon: Icon) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.4))
                .frame(width: 32, height: 32)
            
            switch icon {
            case .system(let systemName):
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yellow)
            case .asset(let assetName):
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.yellow)
            }
        }
    }
}


#Preview {
    VStack(spacing: 16) {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(
                    icon: "waveform",
                    title: SettingsTabCopy.Keyboard.hapticsTitle,
                    description: SettingsTabCopy.Keyboard.hapticsDescription,
                    isOn: .constant(true)
                )
            }
        }
        
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(
                    icon: "mic.fill",
                    title: "Prefer Built-In Microphone",
                    description: "KeyVox will prefer the built-in microphone whenever one is available.",
                    isOn: .constant(false)
                )
            }
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}
