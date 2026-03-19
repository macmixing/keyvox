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
    static let height: CGFloat = 150
    static let actionButtonWidth: CGFloat = 126
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
                AppActionButton(
                    title: config.cancelButtonTitle,
                    style: .secondary,
                    minWidth: ConfirmDeletePromptLayout.actionButtonWidth,
                    action: onCancel
                )

                AppActionButton(
                    title: config.confirmButtonTitle,
                    style: .destructive,
                    minWidth: ConfirmDeletePromptLayout.actionButtonWidth,
                    action: onConfirm
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .frame(width: ConfirmDeletePromptLayout.width, height: ConfirmDeletePromptLayout.height)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                MacAppTheme.screenBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MacAppTheme.windowStroke, lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}
