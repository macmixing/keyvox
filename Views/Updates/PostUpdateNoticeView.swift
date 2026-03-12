import SwiftUI

struct PostUpdateNoticeView: View {
    let version: String
    let onDismiss: () -> Void

    static let preferredWindowSize = CGSize(width: 360, height: 190)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedWaveHeader()

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You've been updated to v\(version)")
                        .font(.custom("Kanit Medium", size: 18))
                        .foregroundColor(.white)

                    Text("KeyVox is ready to go with the latest improvements.")
                        .font(.custom("Kanit Medium", size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }

            HStack {
                Spacer()

                Button("Okay", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
            }
        }
        .padding(20)
        .frame(width: Self.preferredWindowSize.width, height: Self.preferredWindowSize.height)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.9)
            }
        )
        .preferredColorScheme(.dark)
    }
}
