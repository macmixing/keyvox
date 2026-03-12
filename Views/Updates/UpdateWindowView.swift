import SwiftUI

struct UpdateWindowView: View {
    @ObservedObject var coordinator: AppUpdateCoordinator

    static let preferredWindowSize = CGSize(width: 520, height: 500)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnimatedWaveHeader {
                StatusBadge(title: "Updater", color: .indigo)
            }

            UpdateHeaderCard(
                currentVersion: coordinator.currentVersion,
                targetVersion: coordinator.targetVersion,
                statusMessage: coordinator.statusMessage,
                state: coordinator.state
            )

            if !coordinator.releaseNotesPreview.isEmpty {
                UpdateReleaseNotesCard(releaseNotes: coordinator.releaseNotesPreview)
            }

            if coordinator.state == .requiresApplicationsInstall {
                UpdateApplicationsRequirementCard()
            }

            if coordinator.state == .downloading ||
                coordinator.state == .verifyingChecksum ||
                coordinator.state == .extracting ||
                coordinator.state == .verifyingSignature ||
                coordinator.state == .readyToInstall ||
                coordinator.state == .installing {
                UpdateProgressCard(
                    progress: coordinator.progress,
                    statusMessage: coordinator.statusMessage,
                    downloadedBytes: coordinator.downloadedBytes,
                    totalBytes: coordinator.totalBytes
                )
            }

            if let failureMessage = coordinator.failureMessage,
               coordinator.state == .failed {
                UpdateFailureCard(message: failureMessage)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(coordinator.secondaryButtonTitle) {
                    coordinator.secondaryAction()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(coordinator.primaryButtonTitle) {
                    coordinator.primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(!coordinator.canTriggerPrimaryAction)
            }
        }
        .padding(20)
        .frame(width: Self.preferredWindowSize.width, height: Self.preferredWindowSize.height)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.94)
            }
        )
        .preferredColorScheme(.dark)
    }
}
