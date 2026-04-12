import SwiftUI

struct SettingsRow<TrailingContent: View>: View {
    let icon: String?
    let title: String
    let description: String
    let trailingContent: TrailingContent
    
    init(
        icon: String? = nil,
        title: String,
        description: String,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.trailingContent = trailingContent()
    }
    
    init(
        icon: String? = nil,
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) where TrailingContent == AnyView {
        self.icon = icon
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
    
    private func iconView(_ systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.4))
                .frame(width: 32, height: 32)
            
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.yellow)
        }
    }
}


#Preview {
    VStack(spacing: 16) {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(
                    icon: "waveform",
                    title: "Keyboard Haptics",
                    description: "Get haptic feedback from KeyVox Keyboard",
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
