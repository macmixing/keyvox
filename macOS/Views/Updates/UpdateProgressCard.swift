import Foundation
import SwiftUI

struct UpdateProgressCard: View {
    let progress: Double
    let statusMessage: String
    let downloadedBytes: Int64
    let totalBytes: Int64

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private var detailText: String? {
        guard totalBytes > 0 else { return nil }
        return String(localized: "\(AppTypography.fontSupportedSpacing(Self.byteFormatter.string(fromByteCount: downloadedBytes))) of \(AppTypography.fontSupportedSpacing(Self.byteFormatter.string(fromByteCount: totalBytes)))", comment: "Download size progress in the KeyVox update window. The first %@ is the amount downloaded and the second %@ is the total size; both are formatted file sizes.")
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Download Progress", comment: "Title of the progress card in the KeyVox update window.")
                    .font(.appFont(15))
                    .foregroundColor(.white)

                AppUpdateProgressBar(
                    progress: progress,
                    label: statusMessage,
                    detail: detailText
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
