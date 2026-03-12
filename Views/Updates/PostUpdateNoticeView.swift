import SwiftUI

struct PostUpdateNoticeView: View {
    let version: String
    let onDismiss: () -> Void

    static let preferredWindowSize = CGSize(width: 420, height: 280)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedWaveHeader {
                StatusBadge(title: "Updated", color: .indigo)
            }
            .padding(.top, 10)

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You've been updated to v\(version)")
                        .font(.appFont(20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("KeyVox is ready to go with the latest improvements.")
                        .font(.appFont(12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack {
                AppActionButton(
                    title: "Okay",
                    style: .primary,
                    minWidth: 160,
                    action: onDismiss
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(width: Self.preferredWindowSize.width, height: Self.preferredWindowSize.height)
        .background(
            Color.indigo.opacity(0.15)
                .background(Color(white: 0.01))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}
