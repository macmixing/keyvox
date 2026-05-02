import KeyVoxStyleRewrite
import SwiftUI

struct KeyVoxVibesSceneAView: View {
    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    LogoBarView(size: 74)
                        .padding(.bottom, 24)

                    Text("KeyVox Vibes")
                        .font(.appFont(35, variant: .medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)

                    Text("On-device writing styles for your dictated words.")
                        .font(.appFont(20, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 22)

                    VStack(spacing: 10) {
                        ForEach(StyleRewriteStyle.allCases) { style in
                            exampleRow(style)
                        }
                    }
                    .padding(.bottom, 18)

                    Text("Built with Apple Intelligence and KeyVox formatting rules.")
                        .font(.appFont(16, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 42)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func exampleRow(_ style: StyleRewriteStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(style.displayName)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)

            Text(style.exampleText)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.yellow)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
