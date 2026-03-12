import SwiftUI

struct UpdateProgressCard: View {
    let progress: Double
    let statusMessage: String
    let downloadedBytes: Int64
    let totalBytes: Int64

    private var detailText: String? {
        guard totalBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: downloadedBytes)) of \(formatter.string(fromByteCount: totalBytes))"
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Download Progress")
                    .font(.custom("Kanit Medium", size: 15))
                    .foregroundColor(.white)

                AppUpdateProgressBar(
                    progress: progress,
                    label: statusMessage,
                    detail: detailText
                )
            }
        }
    }
}
