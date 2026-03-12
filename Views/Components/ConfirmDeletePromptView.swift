import SwiftUI

struct ConfirmDeletePromptConfig {
    let title: String
    let message: String
    let confirmButtonTitle: String
    let cancelButtonTitle: String

    init(
        title: String,
        message: String,
        confirmButtonTitle: String = "Delete",
        cancelButtonTitle: String = "Cancel"
    ) {
        self.title = title
        self.message = message
        self.confirmButtonTitle = confirmButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
    }
}

private enum ConfirmDeletePromptLayout {
    static let width: CGFloat = 420
    static let height: CGFloat = 130
}

struct ConfirmDeletePromptView: View {
    let config: ConfirmDeletePromptConfig
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(config.title)
                    .font(.appFont(19))
                    .foregroundColor(.white)

                Text(config.message)
                    .font(.appFont(12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Spacer()

                Button(config.cancelButtonTitle, action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button(config.confirmButtonTitle, action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .foregroundColor(.white)
                    .controlSize(.regular)
            }
        }
        .padding(18)
        .frame(width: ConfirmDeletePromptLayout.width, height: ConfirmDeletePromptLayout.height)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.15)
                    .background(Color(white: 0.01))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}
