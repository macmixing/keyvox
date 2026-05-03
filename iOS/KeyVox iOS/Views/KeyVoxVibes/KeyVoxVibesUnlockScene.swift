import SwiftUI

struct KeyVoxVibesUnlockScene: View {
    private struct Benefit: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let benefits: [Benefit] = [
        Benefit(id: 0, icon: "infinity", title: "Vibe Forever", subtitle: "Unlock once and keep every built-in Vibe."),
        Benefit(id: 1, icon: "hand.tap.fill", title: "Long Press Included", subtitle: "Restyle or undo the latest untouched dictation."),
        Benefit(id: 2, icon: "lock.fill", title: "Always Private", subtitle: "Vibes run locally with Apple Intelligence.")
    ]

    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController

    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    Image("vibes-logo-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .padding(.bottom, 14)

                    Text("Want to Keep Vibing?")
                        .font(.appFont(30, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)

                    Text(subtitle)
                        .font(.appFont(18, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)

                    VStack(spacing: 0) {
                        ForEach(Self.benefits) { benefit in
                            benefitSpotlight(benefit)

                            if benefit.id < Self.benefits.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.bottom, 14)

                    Text("One-time purchase. No subscription.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var subtitle: String {
        if vibesPurchaseController.isTrialActive {
            return "Your trial has \(vibesPurchaseController.trialRemainingText) left."
        }

        return "Experience Vibes for life."
    }

    private func benefitSpotlight(_ benefit: Benefit) -> some View {
        VStack(spacing: 4) {
            Image(systemName: benefit.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow)

            Text(benefit.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(benefit.subtitle)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
