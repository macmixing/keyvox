import SwiftUI

struct KeyVoxVibesSceneBView: View {
    private struct Flow: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let flows: [Flow] = [
        Flow(id: 0, icon: "keyboard.fill", title: "Choose Before Dictation", subtitle: "Tap the Vibes key before you stop recording and KeyVox applies that Vibe."),
        Flow(id: 1, icon: "hand.tap.fill", title: "Long Press to Vibe", subtitle: "Change the latest untouched dictation in the text box."),
        Flow(id: 2, icon: "arrow.uturn.backward.circle.fill", title: "Undo the Last Change", subtitle: "Long press again to return to the previous Vibe."),
        Flow(id: 3, icon: "lock.fill", title: "Local First", subtitle: "Text stays on device and uses the same keyboard flow you already know.")
    ]

    let isVisible: Bool

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var disclosureOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    HStack(spacing: 14) {
                        Image("keyvox-vibes")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .opacity(logoOpacity)
                            .scaleEffect(logoScale)

                        VStack(alignment: .leading, spacing: -4) {
                            Text("Set the Vibe")
                                .font(.appFont(33, variant: .medium))
                                .foregroundStyle(.white)

                            Text("Long Press to Vibe, repeat to undo.")
                                .font(.appFont(17, variant: .light))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(headerOpacity)
                    .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        ForEach(Self.flows) { flow in
                            flowRow(flow)
                                .opacity(flow.id < rowRevealProgress ? 1 : 0)
                                .offset(y: flow.id < rowRevealProgress ? 0 : 10)
                        }
                    }

                    Text("Built with Apple Intelligence.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                        .opacity(disclosureOpacity)

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
    }

    private func flowRow(_ flow: Flow) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                if flow.id == 0 {
                    Image("vibes-logo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(.yellow)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: flow.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.yellow)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(flow.title)
                    .font(.appFont(17, variant: .medium))
                    .foregroundStyle(.white)

                Text(flow.subtitle)
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

    private func startEntranceIfNeeded() {
        guard !hasAnimated else { return }
        hasAnimated = true

        stopEntrance()
        logoOpacity = 0
        logoScale = 0.8
        headerOpacity = 0
        rowRevealProgress = 0
        disclosureOpacity = 0

        animationTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                headerOpacity = 1
            }

            for index in Self.flows.indices {
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
