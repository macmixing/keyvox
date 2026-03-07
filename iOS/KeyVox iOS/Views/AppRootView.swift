import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 8) {
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #else
        Color.clear
        #endif
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
}

#Preview {
    AppRootView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
}
