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
        Flow(id: 1, icon: "hand.tap.fill", title: "Long Press to Vibe", subtitle: "Change the latest untouched dictation after it lands."),
        Flow(id: 2, icon: "arrow.uturn.backward.circle.fill", title: "Undo the Last Change", subtitle: "Long press again to return to the previous Vibe."),
        Flow(id: 3, icon: "lock.fill", title: "Local First", subtitle: "Text stays on device and uses the same keyboard flow you already know.")
    ]

    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.4))
                                .frame(width: 52, height: 52)

                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.yellow)
                        }

                        VStack(alignment: .leading, spacing: -4) {
                            Text("Long Press to Vibe")
                                .font(.appFont(33, variant: .medium))
                                .foregroundStyle(.white)

                            Text("No commitment. Change your mind after dictation.")
                                .font(.appFont(17, variant: .light))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        ForEach(Self.flows) { flow in
                            flowRow(flow)
                        }
                    }

                    Text("Vibes are currently supported for English only.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func flowRow(_ flow: Flow) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: flow.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.yellow)
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
}
