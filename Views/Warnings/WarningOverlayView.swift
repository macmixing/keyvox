import SwiftUI

struct WarningOverlayView: View {
    let kind: WarningKind
    let openSystemSettings: () -> Void
    let openKeyVoxSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow)
                Text(kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text(kind.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            if kind.systemSettingsURL != nil && kind.showsKeyVoxSettingsButton {
                HStack(spacing: 8) {
                    Button("System Settings", action: openSystemSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("KeyVox Settings", action: openKeyVoxSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
            } else {
                HStack {
                    Spacer(minLength: 0)
                    if kind.showsKeyVoxSettingsButton {
                        Button("KeyVox Settings", action: openKeyVoxSettings)
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .controlSize(.small)
                    } else {
                        Button("System Settings", action: openSystemSettings)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
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
