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

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var footerOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    Image("vibes-logo-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 14)

                    Text("Want to Keep Vibing?")
                        .font(.appFont(30, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .padding(.bottom, 6)

                    Text(subtitle)
                        .font(.appFont(18, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 16)

                    VStack(spacing: 0) {
                        ForEach(Self.benefits) { benefit in
                            benefitSpotlight(benefit)
                                .opacity(benefit.id < rowRevealProgress ? 1 : 0)
                                .offset(y: benefit.id < rowRevealProgress ? 0 : 12)

                            if benefit.id < Self.benefits.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                                    .opacity(benefit.id + 1 < rowRevealProgress ? 1 : 0)
                            }
                        }
                    }
                    .padding(.bottom, 14)

                    Text("One-time purchase. No subscription.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(footerOpacity)

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .onChange(of: isVisible, initial: true) { _, visible in
            guard visible else { return }
            startEntranceIfNeeded()
        }
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

    private func startEntranceIfNeeded() {
        guard !hasAnimated else { return }
        hasAnimated = true

        stopEntrance()
        logoOpacity = 0
        logoScale = 0.7
        titleOpacity = 0
        subtitleOpacity = 0
        rowRevealProgress = 0
        footerOpacity = 0

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                subtitleOpacity = 1
            }

            for index in Self.benefits.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                footerOpacity = 1
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
