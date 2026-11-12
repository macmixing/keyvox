import Foundation
import SwiftUI

struct MacVibesIntroSceneBView: View {
    private struct Flow: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let flows: [Flow] = [
        Flow(id: 0, icon: "keyboard.fill", title: String(localized: "What's Your Vibe?", comment: "Feature title in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English."), subtitle: String(localized: "Double tap the trigger key to cycle through Vibes or select one in Settings.", comment: "Feature description in the KeyVox Vibes introduction window. Settings is the KeyVox settings window. Vibe, Vibes and Vibes AI are brand names and stay in English.")),
        Flow(id: 1, icon: "hand.tap.fill", title: String(localized: "Tap to Vibe", comment: "Feature title in the KeyVox Vibes introduction window about tapping the trigger key to apply a Vibe. Vibe, Vibes and Vibes AI are brand names and stay in English."), subtitle: String(localized: "Tap the trigger key to change the Vibe for the latest untouched dictation in the text box.", comment: "Feature description in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English.")),
        Flow(id: 2, icon: "arrow.uturn.backward.circle.fill", title: String(localized: "Undo the Last Change", comment: "Feature title in the KeyVox Vibes introduction window."), subtitle: String(localized: "Tap again to return to the previous Vibe.", comment: "Feature description in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English.")),
        Flow(id: 3, icon: "lock.fill", title: String(localized: "Local First", comment: "Feature title in the KeyVox Vibes introduction window about Vibes running on the Mac without the cloud."), subtitle: String(localized: "Vibes AI doesn't rely on the cloud. Your words stay on your Mac.", comment: "Feature description in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English."))
    ]

    let isVisible: Bool

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image("keyvox-vibes")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)

                VStack(alignment: .leading, spacing: -4) {
                    Text("Set the Vibe", comment: "Title of the how-to page in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English.")
                        .font(.appFont(33, variant: .medium))
                        .foregroundStyle(.white)

                    Text("Tap to Vibe, repeat to undo.", comment: "Subtitle of the how-to page in the KeyVox Vibes introduction window. Vibe, Vibes and Vibes AI are brand names and stay in English.")
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
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            handleVisibilityChange(isVisible)
        }
        .onChange(of: isVisible) { visible in
            handleVisibilityChange(visible)
        }
    }

    private func handleVisibilityChange(_ visible: Bool) {
        guard visible else { return }
        startEntranceIfNeeded()
    }

    private func flowRow(_ flow: Flow) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MacAppTheme.iconFill)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(MacAppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MacAppTheme.rowStroke, lineWidth: 1)
                )
        )
    }

    private func startEntranceIfNeeded() {
        guard hasAnimated == false else { return }
        hasAnimated = true

        stopEntrance()
        logoOpacity = 0
        logoScale = 0.8
        headerOpacity = 0
        rowRevealProgress = 0

        animationTask = Task { @MainActor in
            guard Task.isCancelled == false else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                headerOpacity = 1
            }

            for index in Self.flows.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard Task.isCancelled == false else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
