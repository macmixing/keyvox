import QuartzCore
import SwiftUI

extension WindowManager {
    @MainActor
    func showFirstDictationOnboarding() {
        if let existing = firstDictationOnboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowSize = FirstDictationOnboardingWindowMetrics.introSize
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
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

        window.contentView = NSHostingView(rootView: FirstDictationOnboardingFlowView(
            onWindowSizeChange: { [weak window] newSize, completion in
                window?.animateFirstDictationContentSize(to: newSize, completion: completion)
            },
            onComplete: { completion in
                switch completion {
                case .completed:
                    AppSettingsStore.shared.hasCompletedFirstDictation = true
                case .skipped:
                    AppSettingsStore.shared.hasSkippedFirstDictation = true
                }

                window.close()
                self.firstDictationOnboardingWindow = nil
                self.openSettings(centered: true)
                KeyVoxApp.presentVibesIntroIfEligibleAfterUpdateGate()
            }
        ))

        window.setContentSize(windowSize)
        window.center()
        firstDictationOnboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DockIconVisibilityController.shared.syncActivationPolicy()
    }
}

private extension NSWindow {
    func animateFirstDictationContentSize(
        to newSize: CGSize,
        completion: @escaping () -> Void
    ) {
        let currentFrame = frame
        setContentSize(newSize)
        center()
        let centeredFrame = frame
        setFrame(currentFrame, display: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(centeredFrame, display: true)
        } completionHandler: {
            completion()
        }
    }
}
