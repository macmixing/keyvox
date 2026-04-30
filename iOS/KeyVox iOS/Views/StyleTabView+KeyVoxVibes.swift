import SwiftUI
import KeyVoxStyleRewrite

extension StyleTabView {
    @ViewBuilder
    var keyVoxVibesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("KeyVox Vibes")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.selectedVibe.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Picker("", selection: keyVoxVibesSelection) {
                            ForEach(StyleRewriteStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Text("Change")
                            .font(.appFont(16))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                Text(keyVoxVibesDescription)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var keyVoxVibesDescription: String {
        settingsStore.selectedVibe.description
    }

    private var keyVoxVibesSelection: Binding<StyleRewriteStyle> {
        Binding(
            get: { settingsStore.selectedVibe },
            set: { newValue in
                settingsStore.selectedVibe = newValue
            }
        )
    }
}
