import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager
    @EnvironmentObject private var modelManager: iOSModelManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            modelSection
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
        .padding(16)
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
                case .downloading:
                    Text("Downloading...")
                        .font(.footnote.monospaced())
                case .installing:
                    Text("Installing...")
                        .font(.footnote.monospaced())
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
        switch modelManager.installState {
        case .notInstalled:
            return "Model: not installed"
        case .downloading(let progress):
            return "Model: downloading \(Int(progress * 100))%"
        case .installing:
            return "Model: installing"
        case .ready:
            return "Model: ready"
        case .failed(let message):
            return "Model: failed (\(message))"
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.modelManager)
}
