import AppKit
import SwiftUI

extension WindowManager {
    @MainActor
    func showVibesIntroWindow(initialScene: MacVibesIntroScene) {
        let window: NSWindow
        if let existing = vibesIntroWindow {
            window = existing
        } else {
            let preferredSize = initialScene.preferredWindowSize
            window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: preferredSize.width,
                    height: preferredSize.height
                ),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.level = .floating
            window.hidesOnDeactivate = false
            vibesIntroWindow = window
        }

        let hostingView = NSHostingView(
            rootView:
                MacVibesIntroWindowView(
                    initialScene: initialScene,
                    dictationModel: AppSettingsStore.shared.activeDictationProvider.styleRewriteDictationModel,
                    localRewriteModelManager: AppServiceRegistry.shared.localRewriteModelManager,
                    onPreferredSizeChange: { [weak window] preferredSize in
                        guard let window else { return }
                        self.resizeVibesIntroWindow(window, to: preferredSize)
                    },
                    onDismiss: { [weak window] in
                        window?.close()
                        self.vibesIntroWindow = nil
                        DockIconVisibilityController.shared.syncActivationPolicy()
                    },
                    onTryIt: { [weak window] in
                        window?.close()
                        self.vibesIntroWindow = nil
                        DockIconVisibilityController.shared.syncActivationPolicy()
                        self.openSettings(tab: .style)
                    }
                )
                .keyVoxWindowDragGesture(allowsActivationEvents: true)
            )

        window.contentView = hostingView
        window.setContentSize(
            resolvedVibesIntroContentSize(
                hostingView: hostingView,
                fallback: initialScene.preferredWindowSize
            )
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DockIconVisibilityController.shared.syncActivationPolicy()
    }

    @MainActor
    private func resolvedVibesIntroContentSize<Content: View>(
        hostingView: NSHostingView<Content>,
        fallback: CGSize
    ) -> CGSize {
        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else {
            return fallback
        }

        return fittingSize
    }

    @MainActor
    private func resizeVibesIntroWindow(_ window: NSWindow, to contentSize: CGSize) {
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        frame.origin.x = window.frame.minX
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true, animate: false)
    }
}
