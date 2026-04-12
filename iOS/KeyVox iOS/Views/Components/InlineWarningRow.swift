import SwiftUI

struct InlineWarningRow: View {
    enum AlignmentMode {
        case leading
        case centered
    }

    enum Copy {
        static let cellularDownloadRecommended = "Wi-Fi is recommended for this download."
        static let cellularModelDownloadRecommended = "Wi-Fi is recommended to download."
    }

    let text: String
    var fontSize: CGFloat = 14
    var iconSize: CGFloat = 12
    var spacing: CGFloat = 6
    var alignmentMode: AlignmentMode = .leading

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.yellow)

            Text(text)
                .font(.appFont(fontSize, variant: .light))
                .foregroundStyle(.yellow.opacity(0.92))
                .frame(
                    maxWidth: alignmentMode == .leading ? .infinity : nil,
                    alignment: alignmentMode == .leading ? .leading : .center
                )
        }
    }
}
