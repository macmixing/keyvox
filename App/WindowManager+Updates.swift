import AppKit
import SwiftUI

extension WindowManager {
    @MainActor
    func openUpdateWindow(centered: Bool = true) {
        let window: NSWindow
        let isNewWindow: Bool
        if let existing = updateWindow {
            window = existing
            isNewWindow = false
        } else {
            window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: UpdateWindowView.preferredWindowSize.width,
                    height: UpdateWindowView.preferredWindowSize.height
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
            window.isMovableByWindowBackground = false
            updateWindow = window
            isNewWindow = true
        }

        window.contentView = NSHostingView(
            rootView: UpdateWindowView(
                coordinator: AppUpdateCoordinator.shared,
                onPreferredHeightChange: { [weak window] height in
                    guard let window else { return }
                    let targetSize = CGSize(
                        width: UpdateWindowView.preferredWindowSize.width,
                        height: height
                    )
                    if window.contentLayoutRect.size != targetSize {
                        window.setContentSize(targetSize)
                        self.centerUpdateWindow(window)
                    }
                }
            )
        )
        if isNewWindow {
            window.setContentSize(UpdateWindowView.preferredWindowSize)
        }
        if centered {
            centerUpdateWindow(window)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func hideUpdateWindow() {
        updateWindow?.orderOut(nil)
    }

    @MainActor
    func showPostUpdateNoticeWindow() {
        guard let version = AppUpdateCoordinator.shared.postUpdateNoticeVersion else { return }

        let window: NSWindow
        if let existing = postUpdateNoticeWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: PostUpdateNoticeView.preferredWindowSize.width,
                    height: PostUpdateNoticeView.preferredWindowSize.height
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
            window.isMovableByWindowBackground = false
            postUpdateNoticeWindow = window
        }

        window.contentView = NSHostingView(
            rootView: PostUpdateNoticeView(
                version: version,
                onDismiss: {
                    AppUpdateCoordinator.shared.dismissPostUpdateNotice()
                }
            )
        )
        window.setContentSize(PostUpdateNoticeView.preferredWindowSize)
        centerFloatingWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func hidePostUpdateNoticeWindow() {
        postUpdateNoticeWindow?.orderOut(nil)
    }

    @MainActor
    private func centerUpdateWindow(_ window: NSWindow) {
        centerFloatingWindow(window)
    }

    @MainActor
    private func centerFloatingWindow(_ window: NSWindow) {
        let screen = window.screen ?? NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - (windowSize.width / 2),
            y: visibleFrame.midY - (windowSize.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}
