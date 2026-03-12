import AppKit
import SwiftUI

struct UpdateWindowView: View {
    private struct HeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = UpdateWindowView.preferredWindowSize.height

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    @ObservedObject var coordinator: AppUpdateCoordinator
    var onPreferredHeightChange: (CGFloat) -> Void = { _ in }

    static let preferredWindowSize = CGSize(width: 520, height: 300)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            draggableContent
            actionRow
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: HeightPreferenceKey.self,
                    value: geometry.size.height
                )
            }
        )
        .frame(width: Self.preferredWindowSize.width)
        .frame(minHeight: Self.preferredWindowSize.height)
        .background(
            MacAppTheme.screenBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .preferredColorScheme(.dark)
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            onPreferredHeightChange(max(Self.preferredWindowSize.height, height))
        }
    }

    private var draggableContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedWaveHeader {
                StatusBadge(title: "Updater", color: MacAppTheme.accent)
            }
            .padding(.top, 10)
            .background(WindowDragRegion())

            UpdateHeaderCard(
                currentVersion: coordinator.currentVersion,
                targetVersion: coordinator.targetVersion,
                statusMessage: coordinator.statusMessage,
                state: coordinator.state
            )

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
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            AppActionButton(
                title: coordinator.secondaryButtonTitle,
                style: .secondary,
                minWidth: 190
            ) {
                coordinator.secondaryAction()
            }

            Spacer()

            AppActionButton(
                title: coordinator.primaryButtonTitle,
                style: .primary,
                minWidth: 190,
                isEnabled: coordinator.canTriggerPrimaryAction
            ) {
                coordinator.primaryAction()
            }
        }
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

private final class DragRegionView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
