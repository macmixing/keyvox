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
                    Spacer(minLength: 24)

                    Image("vibes-logo-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 12)

                    Text("Vibes Are for Life")
                        .font(.appFont(31, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .padding(.bottom, 6)

                    Text("Try for a day. Unlock for a lifetime.")
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 18)

                    VStack(spacing: 0) {
                        ForEach(Self.details) { detail in
                            detailSpotlight(detail)
                                .opacity(detail.id < rowRevealProgress ? 1 : 0)
                                .offset(y: detail.id < rowRevealProgress ? 0 : 12)

                            if detail.id < Self.details.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                                    .opacity(detail.id + 1 < rowRevealProgress ? 1 : 0)
                            }
                        }
                    }
                    .padding(.bottom, 14)

                    Text("One-time purchase. No subscription.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .opacity(footerOpacity)

                    Spacer(minLength: 48)
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
        .onDisappear {
            stopEntrance()
        }
    }

    private func detailSpotlight(_ detail: Detail) -> some View {
        VStack(spacing: 4) {
            Image(systemName: detail.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow)

            Text(detail.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(detail.subtitle)
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

            for index in Self.details.indices {
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
