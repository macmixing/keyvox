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
            ProgressView(value: clampedProgress)
                .progressViewStyle(KeyVoxProgressStyle())
                .frame(height: 8)

            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.appFont(11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(clampedProgress * 100))%")
                    .font(.appFont(11))
                    .foregroundColor(MacAppTheme.accent)
            }

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
