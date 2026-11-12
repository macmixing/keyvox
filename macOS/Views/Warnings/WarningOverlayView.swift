import Foundation
import SwiftUI

struct WarningOverlayView: View {
    let kind: WarningKind
    let openSystemSettings: () -> Void
    let openKeyVoxSettings: () -> Void
    private let contentRailWidth: CGFloat = 214

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.yellow)
                Text(kind.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text(kind.message)
                .font(.appFont(11, variant: .light))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack(spacing: 8) {
                if kind.systemSettingsURL != nil {
                    Button(String(localized: "System Settings", comment: "Button on the warning panel that opens macOS System Settings. Use the name macOS uses for System Settings in this language."), action: openSystemSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                if kind.showsKeyVoxSettingsButton {
                    Button(String(localized: "KeyVox Settings", comment: "Button on the warning panel that opens the KeyVox settings window. KeyVox is a brand name and stays in English."), action: openKeyVoxSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: contentRailWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(14)
        .frame(width: 260)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
