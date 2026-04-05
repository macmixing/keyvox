import SwiftUI

struct KeyVoxSpeakSceneBView: View {
    private struct AccessMethod: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let accessMethods: [AccessMethod] = [
        AccessMethod(id: 0, icon: "house.fill", title: "Home Tab", subtitle: "Tap Speak from the main screen."),
        AccessMethod(id: 1, icon: "keyboard.fill", title: "Keyboard Shortcut", subtitle: "Trigger directly from the KeyVox keyboard."),
        AccessMethod(id: 2, icon: "square.and.arrow.up.fill", title: "Share to Speak", subtitle: "Share text, URLs, or images with text from any app."),
        AccessMethod(id: 3, icon: "link", title: "Shortcuts & Actions", subtitle: "Map to Action Button or Control Center.")
    ]

    @State private var circleOpacity: Double = 0
    @State private var circleScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var fastModeCardOpacity: Double = 0
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
                            Text("How To Speak?")
                                .font(.appFont(30, variant: .medium))
                                .foregroundStyle(.white)

                            Text("Speak is everywhere you are.")
                                .font(.appFont(16, variant: .light))
                                .foregroundStyle(.white.opacity(0.7))
                        }
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

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .onAppear { startEntrance() }
        .onDisappear { stopEntrance() }
    }

    private var fastModeCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Fast Mode Available")
                    .font(.appFont(14, variant: .medium))
                    .foregroundStyle(.white)

                Text("Starts speaking ~50% faster. Toggle in the toolbar.")
                    .font(.appFont(12, variant: .light))
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(method.title)
                    .font(.appFont(15, variant: .medium))
                    .foregroundStyle(.white)

                Text(method.subtitle)
                    .font(.appFont(13, variant: .light))
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

    private func startEntrance() {
        guard !hasAnimated else { return }
        hasAnimated = true
        
        stopEntrance()
        circleOpacity = 0
        circleScale = 0.8
        headerOpacity = 0
        rowRevealProgress = 0
        fastModeCardOpacity = 0

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
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
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
