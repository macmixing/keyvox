import SwiftUI

struct ModelDownloadProgress: View {
    let progress: Double
    var showLabel: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            if showLabel {
                HStack {
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.appFont(11))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(KeyVoxProgressStyle())
                .frame(height: 6)
        }
    }
}

struct KeyVoxProgressStyle: ProgressViewStyle {
    var fillColor: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))

                if let progress = configuration.fractionCompleted {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .shadow(color: fillColor.opacity(0.5), radius: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ModelDownloadProgress(progress: 0.0)
            .frame(width: 300)
        ModelDownloadProgress(progress: 0.35)
            .frame(width: 300)
        ModelDownloadProgress(progress: 0.75)
            .frame(width: 300)
        ModelDownloadProgress(progress: 1.0)
            .frame(width: 300)
    }
    .padding()
    .background(AppTheme.screenBackground)
}
