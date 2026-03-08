import SwiftUI
import KeyVoxCore

struct AppRootView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager
    @EnvironmentObject private var modelManager: iOSModelManager
    @EnvironmentObject private var settingsStore: iOSAppSettingsStore
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modelSection
                settingsSection
                dictionarySection
                #if DEBUG
                Text(statusText)
                    .font(.footnote.monospaced())
                if let artifact = transcriptionManager.lastCaptureArtifact {
                    Text("Last capture: \(artifact.outputFrameCount) output frames")
                        .font(.footnote.monospaced())
                }
                if let error = transcriptionManager.lastErrorMessage {
                    Text(error)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.red)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            modelManager.refreshStatus()
        }
    }

    private var statusText: String {
        switch transcriptionManager.state {
        case .idle:
            return "State: idle"
        case .recording:
            return "State: recording"
        case .processingCapture:
            return "State: processingCapture"
        case .transcribing:
            return "State: transcribing"
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(modelStatusText)
                .font(.footnote.monospaced())

            if let error = modelManager.errorMessage {
                Text(error)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                switch modelManager.installState {
                case .notInstalled:
                    Button("Download Model") {
                        modelManager.downloadModel()
                    }
                case .downloading, .installing:
                    if let actionText = modelManager.installState.actionText {
                        Text(actionText)
                            .font(.footnote.monospaced())
                    }
                case .ready:
                    Button("Delete Model") {
                        modelManager.deleteModel()
                    }
                case .failed:
                    Button("Repair Model") {
                        modelManager.repairModelIfNeeded()
                    }
                    Button("Delete Model") {
                        modelManager.deleteModel()
                    }
                }
            }
        }
    }

    private var modelStatusText: String {
        modelManager.installState.statusText
    }

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)

            Toggle("Auto paragraphs", isOn: $settingsStore.autoParagraphsEnabled)
            Toggle("List formatting", isOn: $settingsStore.listFormattingEnabled)
        }
    }

    @ViewBuilder
    private var dictionarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dictionary")
                .font(.headline)

            if dictionaryStore.entries.isEmpty {
                Text("No dictionary entries yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dictionaryStore.entries) { entry in
                        Text(entry.phrase)
                            .font(.footnote.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
        .environmentObject(iOSAppServiceRegistry.shared.settingsStore)
        .environmentObject(iOSAppServiceRegistry.shared.dictionaryStore)
}
