import SwiftUI

struct TTSReplayScrubber: View {
    let progress: Double
    let currentTimeSeconds: Double
    let durationSeconds: Double
    let onScrub: (Double) -> Void

    @State private var scrubProgress: Double
    @State private var isScrubbing = false

    init(
        progress: Double,
        currentTimeSeconds: Double,
        durationSeconds: Double,
        onScrub: @escaping (Double) -> Void
    ) {
        self.progress = progress
        self.currentTimeSeconds = currentTimeSeconds
        self.durationSeconds = durationSeconds
        self.onScrub = onScrub
        _scrubProgress = State(initialValue: progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Slider(
                value: Binding(
                    get: { scrubProgress },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1,
                onEditingChanged: handleEditingChanged
            )
            .tint(.yellow)
            .animation(.linear(duration: 1.0 / 30.0), value: scrubProgress)

            HStack(spacing: 12) {
                Text(formattedTime(isScrubbing ? durationSeconds * scrubProgress : currentTimeSeconds))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedTime(durationSeconds))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.appFont(13, variant: .medium))
            .foregroundStyle(.yellow.opacity(0.95))
            .monospacedDigit()
        }
        .onChange(of: progress, initial: true) { _, newValue in
            guard isScrubbing == false else { return }
            scrubProgress = newValue
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        isScrubbing = editing
        if editing == false {
            onScrub(scrubProgress)
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let clampedSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
