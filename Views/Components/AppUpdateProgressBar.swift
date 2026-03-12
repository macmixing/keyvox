import SwiftUI

struct AppUpdateProgressBar: View {
    let progress: Double
    let label: String
    let detail: String?

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(KeyVoxProgressStyle())
                .frame(height: 8)

            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.custom("Kanit Medium", size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.custom("Kanit Medium", size: 11))
                    .foregroundColor(.indigo)
            }

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.custom("Kanit Medium", size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
