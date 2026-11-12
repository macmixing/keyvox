import Foundation
import SwiftUI

struct KeyVoxSpeakSceneBView: View {
    private struct AccessMethod: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let accessMethods: [AccessMethod] = [
        AccessMethod(id: 0, icon: "house.fill", title: String(localized: "Home Tab", comment: "Row title on the KeyVox Speak page listing the ways to start Speak: from the app's Home tab."), subtitle: String(localized: "Tap Speak from the main screen.", comment: "Row description on the KeyVox Speak page listing the ways to start Speak. Speak is the name of the button and a brand name; it stays in English.")),
        AccessMethod(id: 1, icon: "keyboard.fill", title: String(localized: "Keyboard Shortcut", comment: "Row title on the KeyVox Speak page listing the ways to start Speak: a button on the KeyVox keyboard."), subtitle: String(localized: "Trigger directly from the KeyVox keyboard.", comment: "Row description on the KeyVox Speak page listing the ways to start Speak. KeyVox is a brand name and stays in English.")),
        AccessMethod(id: 2, icon: "square.and.arrow.up.fill", title: String(localized: "Share to Speak", comment: "Row title on the KeyVox Speak page listing the ways to start Speak: sharing content to KeyVox Speak from the share sheet. Speak is a brand name and stays in English."), subtitle: String(localized: "Share PDFs, websites, and images with text from any app.", comment: "Row description on the KeyVox Speak page listing the ways to start Speak.")),
        AccessMethod(
            id: 3,
            icon: "link",
            title: String(localized: "Shortcuts & Actions", comment: "Row title on the KeyVox Speak page listing the ways to start Speak: system shortcuts and the Action Button."),
            subtitle: AppDevice.isPad ? String(localized: "Map to Control Center.", comment: "Row description on the KeyVox Speak page listing the ways to start Speak, shown on iPad. Use Apple's official name for Control Center in this language.") : String(localized: "Map to Action Button or Control Center.", comment: "Row description on the KeyVox Speak page listing the ways to start Speak. Use Apple's official names for the Action Button and Control Center in this language.")
        )
    ]

    let isVisible: Bool
    var isUnlockContext: Bool = false

    @State private var circleOpacity: Double = 0
    @State private var circleScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var fastModeCardOpacity: Double = 0
    @State private var disclosureOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    HStack(spacing: 14) {
                        Image("keyvox-speak")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .opacity(circleOpacity)
                            .scaleEffect(circleScale)
                            .shadow(color: .yellow.opacity(0.3), radius: 8)

                        VStack(alignment: .leading, spacing: -6) {
                            Text("Speak Anywhere", comment: "Title of the KeyVox Speak page listing the ways to start Speak. Speak is a brand name and stays in English.")
                                .font(.appFont(35, variant: .medium))
                                .foregroundStyle(.white)

                            Text(isUnlockContext ? String(localized: "All of this. No daily cap.", comment: "Subtitle on the KeyVox Speak unlock page: unlocking removes the daily limit.") : String(localized: "It's everywhere you are.", comment: "Subtitle on the KeyVox Speak page listing the ways to start Speak."))
                                .font(.appFont(18, variant: .light))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(headerOpacity)
                    .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        ForEach(Self.accessMethods) { method in
                            accessMethodRow(method)
                                .opacity(method.id < rowRevealProgress ? 1 : 0)
                                .offset(y: method.id < rowRevealProgress ? 0 : 10)
                        }
                    }
                    .padding(.bottom, 14)

                    fastModeCard
                        .opacity(fastModeCardOpacity)

                    Text("Speak currently supports English only.", comment: "Note on the KeyVox Speak page about language support. Speak is a brand name and stays in English.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
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

    private var fastModeCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Fast Mode Available", comment: "Title of the card on the KeyVox Speak page about the Fast Mode option.")
                    .font(.appFont(16, variant: .medium))
                    .foregroundStyle(.white)

                Text("Starts speaking ~50% faster. Toggle in the toolbar.", comment: "Description of the Fast Mode card on the KeyVox Speak page.")
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                .fill(Color.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func accessMethodRow(_ method: AccessMethod) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: method.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(method.title)
                    .font(.appFont(17, variant: .medium))
                    .foregroundStyle(.white)

                Text(method.subtitle)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
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
        circleOpacity = 0
        circleScale = 0.8
        headerOpacity = 0
        rowRevealProgress = 0
        fastModeCardOpacity = 0
        disclosureOpacity = 0

        animationTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                circleOpacity = 1
                circleScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                headerOpacity = 1
            }

            for index in Self.accessMethods.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                fastModeCardOpacity = 1
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
