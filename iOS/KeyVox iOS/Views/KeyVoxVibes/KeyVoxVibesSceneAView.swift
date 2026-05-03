import KeyVoxStyleRewrite
import SwiftUI

struct KeyVoxVibesSceneAView: View {
    let isVisible: Bool

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var disclosureOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    LogoBarView(size: 74)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 10)

                    Text("KeyVox Vibes")
                        .font(.appFont(35, variant: .medium))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)

                    Text("On-device, reversible writing styles.")
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 10)

                    VStack(spacing: 4) {
                        ForEach(Array(StyleRewriteStyle.allCases.enumerated()), id: \.element.id) { index, style in
                            exampleRow(style)
                                .opacity(index < rowRevealProgress ? 1 : 0)
                                .offset(y: index < rowRevealProgress ? 0 : 10)
                        }
                    }
                    .padding(.bottom, 10)

                    Text("Vibes are currently supported for English only.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(disclosureOpacity)

                    Spacer(minLength: 0)
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

    private func exampleRow(_ style: StyleRewriteStyle) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(style.displayName)
                .font(.appFont(17, variant: .medium))
                .foregroundStyle(.yellow.opacity(0.7))

            Text(style.exampleText)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 17)
        .padding(.top, -3)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.indigo.opacity(0.7))
                .frame(width: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
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
        disclosureOpacity = 0

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

            for index in StyleRewriteStyle.allCases.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.14))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.3)) {
                disclosureOpacity = 1
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
