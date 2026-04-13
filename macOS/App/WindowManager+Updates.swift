import AppKit
import SwiftUI

enum AppUpdateDisplaySelectionLogic {
    static func focusedDisplayKey(
        keyWindowDisplayKey: String?,
        mainWindowDisplayKey: String?,
        mouseDisplayKey: String?,
        mainScreenDisplayKey: String?,
        fallbackDisplayKey: String?
    ) -> String? {
        keyWindowDisplayKey
            ?? mainWindowDisplayKey
            ?? mouseDisplayKey
            ?? mainScreenDisplayKey
            ?? fallbackDisplayKey
    }

    static func interactionDisplayKey(
        mouseDisplayKey: String?,
        focusedDisplayKey: String?
    ) -> String? {
        mouseDisplayKey ?? focusedDisplayKey
    }

    static func resolvedDisplayKey(
        preferredDisplayKey: String?,
        windowDisplayKey: String?,
        focusedDisplayKey: String?,
        mainScreenDisplayKey: String?,
        fallbackDisplayKey: String?
    ) -> String? {
        preferredDisplayKey
            ?? windowDisplayKey
            ?? focusedDisplayKey
            ?? mainScreenDisplayKey
            ?? fallbackDisplayKey
    }
}

@MainActor
final class AppUpdateDisplayCoordinator {
    static let shared = AppUpdateDisplayCoordinator()

    private(set) var preferredDisplayKey: String?

    private init() {}

    var preferredDisplayKeyForResume: String? {
        preferredDisplayKey ?? interactionDisplayKey()
    }

    func captureManualCheckDisplay() {
        preferredDisplayKey = interactionDisplayKey()
    }

    func captureAutomaticPromptDisplay() {
        preferredDisplayKey = focusedDisplayKey()
    }

    func restorePreferredDisplayKeyForResumedUpdate(_ displayKey: String?) {
        preferredDisplayKey = displayKey ?? focusedDisplayKey()
    }

    func preferredScreen(for window: NSWindow? = nil) -> NSScreen? {
        let resolvedDisplayKey = AppUpdateDisplaySelectionLogic.resolvedDisplayKey(
            preferredDisplayKey: preferredDisplayKey,
            windowDisplayKey: displayKey(for: window?.screen),
            focusedDisplayKey: focusedDisplayKey(),
            mainScreenDisplayKey: displayKey(for: NSScreen.main),
            fallbackDisplayKey: displayKey(for: NSScreen.screens.first)
        )

        if let screen = screen(forDisplayKey: resolvedDisplayKey) {
            return screen
        }

        if let screen = window?.screen {
            return screen
        }

        if let screen = NSApp.keyWindow?.screen {
            return screen
        }

        if let screen = NSApp.mainWindow?.screen {
            return screen
        }

        if let screen = screenContaining(point: NSEvent.mouseLocation) {
            return screen
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    private func focusedDisplayKey() -> String? {
        AppUpdateDisplaySelectionLogic.focusedDisplayKey(
            keyWindowDisplayKey: displayKey(for: NSApp.keyWindow?.screen),
            mainWindowDisplayKey: displayKey(for: NSApp.mainWindow?.screen),
            mouseDisplayKey: displayKeyForMouseLocation(),
            mainScreenDisplayKey: displayKey(for: NSScreen.main),
            fallbackDisplayKey: displayKey(for: NSScreen.screens.first)
        )
    }

    private func interactionDisplayKey() -> String? {
        AppUpdateDisplaySelectionLogic.interactionDisplayKey(
            mouseDisplayKey: displayKeyForMouseLocation(),
            focusedDisplayKey: focusedDisplayKey()
        )
    }

    private func displayKeyForMouseLocation() -> String? {
        displayKey(for: screenContaining(point: NSEvent.mouseLocation))
    }

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    private func displayKey(for screen: NSScreen?) -> String? {
        guard let screen else { return nil }
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return String(number.uint32Value)
    }

    private func screen(forDisplayKey key: String?) -> NSScreen? {
        guard let key else { return nil }
        return NSScreen.screens.first(where: { displayKey(for: $0) == key })
    }
}

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
        let screen = AppUpdateDisplayCoordinator.shared.preferredScreen(for: window)
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
