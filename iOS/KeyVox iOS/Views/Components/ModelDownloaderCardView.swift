import SwiftUI

struct ModelDownloaderCardView: View {
    let iconSystemName: String
    let title: String
    let subtitle: String?
    let statusText: String
    let progress: Double?
    let progressText: String?
    let errorText: String?
    let actionTitle: String?
    let actionStyle: AppActionButton.Style
    let isActionEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(AppTheme.accent.opacity(0.32))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 0.5))
                    .overlay {
                        Image(systemName: iconSystemName)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }

                Text(title)
                    .font(.appFont(15, variant: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let actionTitle, progressText == nil {
                    AppActionButton(
                        title: actionTitle,
                        style: actionStyle,
                        size: .compact,
                        fontSize: 14,
                        isEnabled: isActionEnabled,
                        action: action
                    )
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(statusText)
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let progressText {
                    Text(progressText)
                        .font(.appFont(13, variant: .medium))
                        .foregroundStyle(.yellow)
                }
            }

            if let progress {
                ModelDownloadProgress(progress: progress, showLabel: false)
            }

            if let errorText {
                Text(errorText)
                    .font(.appFont(12))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                .fill(AppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                        .stroke(AppTheme.rowStroke, lineWidth: 1)
                )
        )
    }
}
