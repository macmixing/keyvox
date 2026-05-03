import SwiftUI

struct KeyVoxVibesSceneCView: View {
    private struct Detail: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let details: [Detail] = [
        Detail(id: 0, icon: "clock.fill", title: "Try for 24 Hours", subtitle: "Start a local one-day trial and use every Vibe."),
        Detail(id: 1, icon: "infinity", title: "Unlock for Life", subtitle: "One purchase keeps Vibes available forever."),
        Detail(id: 2, icon: "iphone", title: "Device Local", subtitle: "Your selected Vibe stays local to this device.")
    ]

    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    Image("vibes-logo-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .padding(.bottom, 12)

                    Text("Vibes Are for Life")
                        .font(.appFont(31, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)

                    Text("Try for a day. Unlock for a lifetime.")
                        .font(.appFont(18, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 18)

                    VStack(spacing: 12) {
                        ForEach(Self.details) { detail in
                            detailRow(detail)
                        }
                    }
                    .padding(.bottom, 16)

                    Text("One-time purchase. No subscription.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func detailRow(_ detail: Detail) -> some View {
        HStack(spacing: 14) {
            Image(systemName: detail.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(.appFont(17, variant: .medium))
                    .foregroundStyle(.white)

                Text(detail.subtitle)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
