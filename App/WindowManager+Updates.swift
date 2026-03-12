import AppKit
import SwiftUI

extension WindowManager {
    @MainActor
    func openUpdateWindow(centered: Bool = true) {
        let window: NSWindow
        if let existing = updateWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: UpdateWindowView.preferredWindowSize.width,
                    height: UpdateWindowView.preferredWindowSize.height
                ),
                styleMask: [.titled, .fullSizeContentView, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            updateWindow = window
        }

        window.contentView = NSHostingView(rootView: UpdateWindowView(coordinator: AppUpdateCoordinator.shared))
        window.setContentSize(UpdateWindowView.preferredWindowSize)
        if centered {
            window.center()
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
                styleMask: [.titled, .fullSizeContentView, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = true
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
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func hidePostUpdateNoticeWindow() {
        postUpdateNoticeWindow?.orderOut(nil)
    }
}
