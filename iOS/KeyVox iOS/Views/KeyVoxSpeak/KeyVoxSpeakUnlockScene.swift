import Foundation
import SwiftUI

struct KeyVoxSpeakUnlockScene: View {
    private struct Benefit: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let benefits: [Benefit] = [
        Benefit(
            id: 0,
            icon: "infinity",
            title: String(localized: "Unlimited Daily Speaks", comment: "Benefit title on the KeyVox Speak unlock page; Speaks means uses of KeyVox Speak."),
            subtitle: String(localized: "No daily cap. Use it as much as you need.", comment: "Benefit description on the KeyVox Speak unlock page.")
        ),
        Benefit(
            id: 1,
            icon: "lock.fill",
            title: String(localized: "Always Private", comment: "Benefit title on the KeyVox Speak unlock page."),
            subtitle: AppDevice.isPad
                ? String(localized: "AI voices run entirely on-device. Nothing leaves your iPad.", comment: "Benefit description on the KeyVox Speak unlock page, shown on iPad.")
                : String(localized: "AI voices run entirely on-device. Nothing leaves your iPhone.", comment: "Benefit description on the KeyVox Speak unlock page, shown on iPhone.")
        ),
        Benefit(
            id: 2,
            icon: "bolt.fill",
            title: String(localized: "Fast Mode Included", comment: "Benefit title on the KeyVox Speak unlock page."),
            subtitle: String(localized: "Starts speaking ~50% faster with one tap.", comment: "Benefit description on the KeyVox Speak unlock page for Fast Mode.")
        )
    ]

    let isVisible: Bool

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var footerOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    LogoBarView(size: 60)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 14)

                    Text("Get Speak Unlimited", comment: "Title of the KeyVox Speak unlock page. Speak Unlimited is the product name; Speak is a brand name and stays in English.")
                        .font(.appFont(28, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .padding(.bottom, 6)

                    Text("Unlock once. Speak forever.", comment: "Tagline on the KeyVox Speak unlock page.")
                        .font(.appFont(18, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(taglineOpacity)
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

                    Text("One-time purchase. No subscription.", comment: "Pricing note on the KeyVox Speak unlock page.")
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
        taglineOpacity = 0
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
                taglineOpacity = 1
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

#Preview {
    KeyVoxSpeakUnlockScene(isVisible: true)
        .background(AppTheme.screenBackground)
}
