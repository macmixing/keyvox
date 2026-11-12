import Foundation
import SwiftUI

struct InlineWarningRow: View {
    enum AlignmentMode {
        case leading
        case centered
    }

    enum Copy {
        static let cellularDownloadRecommended = String(localized: "Wi-Fi is recommended for this download.", comment: "Warning shown near a download button while the device is on cellular data. Use the system's usual name for Wi-Fi in this language.")
        static let cellularModelDownloadRecommended = String(localized: "Wi-Fi is recommended to download.", comment: "Short warning shown on a model download card while the device is on cellular data. Use the system's usual name for Wi-Fi in this language.")
    }

    let text: String
    var fontSize: CGFloat = 14
    var iconSize: CGFloat = 12
    var spacing: CGFloat = 6
    var alignmentMode: AlignmentMode = .leading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
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
