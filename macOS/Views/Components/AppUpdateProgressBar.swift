import SwiftUI

struct AppUpdateProgressBar: View {
    let progress: Double
    let label: String
    let detail: String?
    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            LabeledProgressBar(progress: clampedProgress, statusText: label)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.appFont(10, variant: .light))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
