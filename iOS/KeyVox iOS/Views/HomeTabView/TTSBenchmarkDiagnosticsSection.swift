#if DEBUG
import SwiftUI
import UIKit

struct TTSBenchmarkDiagnosticsSection: View {
    private enum BenchmarkPreset: String, CaseIterable, Identifiable {
        case short
        case medium
        case long
        case clipboard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .short:
                return "Short"
            case .medium:
                return "Medium"
            case .long:
                return "Long"
            case .clipboard:
                return "Clipboard"
            }
        }

        var text: String? {
            switch self {
            case .short:
                return "KeyVox Speak is measuring time to first audio for this short benchmark sample."
            case .medium:
                return """
                KeyVox Speak is measuring the full end-to-end text to speech pipeline with a medium length passage. This sample is long enough to show how fast the first audio arrives, how quickly the stream becomes replayable, and how much buffered runway exists for background continuation.
                """
            case .long:
                return """
                KeyVox Speak is measuring the full end-to-end text to speech pipeline with a longer benchmark passage designed to stress startup, chunking, replay readiness, and background readiness. This passage intentionally contains enough words to create multiple synthesis chunks so the benchmark can capture per-chunk generation timing, overall generation throughput, replayability timing, and the time it takes for the active playback asset to become safe for background continuation in fast mode.
                """
            case .clipboard:
                return nil
            }
        }
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var audioModeCoordinator: AudioModeCoordinator
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var ttsBenchmarkRecorder: TTSBenchmarkRecorder
    @StateObject private var copyFeedback = CopyFeedbackController()

    @State private var benchmarkText = BenchmarkPreset.medium.text ?? ""
    @State private var lastLoadedPreset: BenchmarkPreset = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TTS Benchmark")
                .font(.appFont(16))
                .foregroundStyle(.white)

            Text(benchmarkStatusText)
                .font(.appFont(12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(BenchmarkPreset.allCases) { preset in
                    Button(preset.title) {
                        applyPreset(preset)
                    }
                    .buttonStyle(.bordered)
                    .tint(lastLoadedPreset == preset ? .yellow : .gray.opacity(0.5))
                }
            }

            TextEditor(text: $benchmarkText)
                .frame(height: 220)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                )
                .font(.appFont(12))
                .foregroundStyle(.white)

            Text(inputMetricsText)
                .font(.appFont(12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(ttsBenchmarkRecorder.isRunning ? "Benchmark Running" : "Run Benchmark") {
                    audioModeCoordinator.handleRunTTSBenchmark(
                        text: benchmarkText,
                        label: benchmarkLabel
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(canRunBenchmark == false)

                Button(copyFeedback.didCopy ? "Copied" : "Copy Summary") {
                    guard let latestSummary = ttsBenchmarkRecorder.latestCompletedRun?.formattedSummary else { return }
                    copyFeedback.copy(latestSummary, appHaptics: appHaptics)
                }
                .buttonStyle(.bordered)
                .disabled(ttsBenchmarkRecorder.latestCompletedRun == nil)

                Button("Clear") {
                    ttsBenchmarkRecorder.clearReports()
                }
                .buttonStyle(.bordered)
                .disabled(ttsBenchmarkRecorder.latestCompletedRun == nil)
            }

            if let latestReport = ttsBenchmarkRecorder.latestCompletedRun {
                ScrollView {
                    Text(latestReport.formattedSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.appFont(12))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 180, maxHeight: 280)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }

    private var benchmarkStatusText: String {
        let mode = settingsStore.fastPlaybackModeEnabled ? "Fast mode on" : "Fast mode off"
        let voice = settingsStore.ttsVoice.displayName
        let readiness = pocketTTSModelManager.isReady(for: settingsStore.ttsVoice)
            ? "Voice ready"
            : "Voice not ready"
        let activity = ttsBenchmarkRecorder.isRunning
            ? "Running \(ttsBenchmarkRecorder.activeLabel ?? "benchmark")"
            : "Ready"
        return "\(activity) • \(mode) • \(voice) • \(readiness)"
    }

    private var benchmarkLabel: String {
        switch lastLoadedPreset {
        case .clipboard:
            return benchmarkText == clipboardBenchmarkText ? "Clipboard" : "Custom"
        case .short where benchmarkText == (BenchmarkPreset.short.text ?? ""):
            return "Short"
        case .medium where benchmarkText == (BenchmarkPreset.medium.text ?? ""):
            return "Medium"
        case .long where benchmarkText == (BenchmarkPreset.long.text ?? ""):
            return "Long"
        default:
            return "Custom"
        }
    }

    private var clipboardBenchmarkText: String {
        UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var canRunBenchmark: Bool {
        benchmarkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && pocketTTSModelManager.isReady(for: settingsStore.ttsVoice)
            && ttsBenchmarkRecorder.isRunning == false
    }

    private var inputMetricsText: String {
        let trimmedText = benchmarkText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmedText.split(whereSeparator: { $0.isWhitespace }).count
        return "\(wordCount) words • \(trimmedText.count) characters"
    }

    private func applyPreset(_ preset: BenchmarkPreset) {
        lastLoadedPreset = preset
        switch preset {
        case .clipboard:
            benchmarkText = clipboardBenchmarkText
        case .short, .medium, .long:
            benchmarkText = preset.text ?? ""
        }
    }
}
#endif
