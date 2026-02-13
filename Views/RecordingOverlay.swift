import SwiftUI
import Combine

// MARK: - Development Settings
private let isDevModeOversized = false // Set to false for normal size

class OverlayVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var shouldDismiss: Bool = false
}

struct RecordingOverlay: View {
    @ObservedObject var recorder: AudioRecorder
    var isTranscribing: Bool
    @ObservedObject var visibilityManager: OverlayVisibilityManager
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Circle()
                        .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                )
                .shadow(radius: 10)
                .frame(width: isDevModeOversized ? 300 : 50, height: isDevModeOversized ? 300 : 50)
            
            HStack(spacing: isDevModeOversized ? 24 : 4) {
                ForEach(0..<5) { index in
                    BarView(
                        value: Double(recorder.audioLevel),
                        index: index,
                        isTranscribing: isTranscribing,
                        signalState: recorder.liveInputSignalState
                    )
                }
            }
        }
        .padding(8)
        .scaleEffect(visibilityManager.isVisible ? 1.0 : 0.3)
        .opacity(visibilityManager.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.88), value: visibilityManager.isVisible)
        .onChange(of: visibilityManager.shouldDismiss) { oldValue, newValue in
            if newValue {
                withAnimation {
                    visibilityManager.isVisible = false
                }
            }
        }
    }
}

struct BarView: View {
    var value: Double
    var index: Int
    var isTranscribing: Bool
    var signalState: LiveInputSignalState
    
    @State private var ripplePhase: Double = 0
    @State private var rippleTimer: Timer?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0) // The "Glow"
            .frame(width: isDevModeOversized ? 24 : 4, height: height)
            .animation(.linear(duration: 0.1), value: ripplePhase)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: value)
            .onAppear {
                startRippleAnimation()
            }
            .onDisappear {
                stopRippleAnimation()
            }
    }
    
    var height: CGFloat {
        let minHeight: CGFloat = isDevModeOversized ? 18 : 6
        let flatHeight: CGFloat = isDevModeOversized ? 9 : 3
        let maxHeight: CGFloat = isDevModeOversized ? 170 : 30

        if isTranscribing {
            // Ripple animation: subtle wave traveling left to right
            let waveOffset = ripplePhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5 // Range: 0.0 to 1.0
            // Thin baseline (3px) with ripple going up to 12px
            return flatHeight + (CGFloat(rippleHeight) * (isDevModeOversized ? 37 : 9))
        }

        if signalState == .dead {
            // Truly silent input: hard flatline.
            return flatHeight
        }

        if signalState == .quiet {
            // Quiet room noise: tiny "live" motion so users know the mic is hot.
            let quietWaveOffset = (ripplePhase * 0.45) + Double(index) * 0.65
            let quietWave = (sin(quietWaveOffset) * 0.5) + 0.5
            let quietLevel = min(max(value / 0.14, 0), 1)
            let subtleBaseLift: CGFloat = isDevModeOversized ? 3.2 : 1.2
            let subtleWaveRange: CGFloat = isDevModeOversized ? 6.8 : 2.6
            return flatHeight + (CGFloat(quietLevel) * subtleBaseLift) + (CGFloat(quietWave) * subtleWaveRange)
        }

        // Normal audio-reactive animation while recording and signal is present.
        let multipliers: [Double] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = CGFloat(value * multipliers[index]) * maxHeight
        return max(minHeight, dynamicHeight)
    }
    
    private func startRippleAnimation() {
        // Prevent stacking multiple timers if the view re-appears
        if rippleTimer != nil { return }

        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Timer tick updates are safe to do on the main run loop (scheduledTimer runs there by default)
            ripplePhase += 0.1
            if ripplePhase > .pi * 2 {
                ripplePhase = 0
            }
        }
    }

    private func stopRippleAnimation() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}

class OverlayManager {
    static let shared = OverlayManager()
    private var window: OverlayPanel?
    private var visibilityManager = OverlayVisibilityManager()
    private var pendingHideWorkItem: DispatchWorkItem?
    private var pendingResetWorkItem: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?
    
    func show(recorder: AudioRecorder, isTranscribing: Bool = false) {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil

        if window == nil {
            let panel = OverlayPanel(
                contentRect: NSRect(x: 0, y: 0, width: isDevModeOversized ? 316 : 66, height: isDevModeOversized ? 316 : 66),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true
            panel.onDoubleClick = { [weak self, weak panel] in
                self?.moveToDefaultPosition(panel, animated: true)
            }
            
            let contentView = NSHostingView(rootView: RecordingOverlay(
                recorder: recorder,
                isTranscribing: isTranscribing,
                visibilityManager: visibilityManager
            ))
            panel.contentView = contentView
            
            panel.setFrameOrigin(initialOrigin(for: panel))
            registerMoveObserverIfNeeded(for: panel)
            
            window = panel
        }
        
        // Always update the content view to ensure binding is fresh
        window?.contentView = NSHostingView(rootView: RecordingOverlay(
            recorder: recorder,
            isTranscribing: isTranscribing,
            visibilityManager: visibilityManager
        ))
        
        // Reset state for showing
        visibilityManager.shouldDismiss = false
        visibilityManager.isVisible = true
        window?.orderFrontRegardless()
    }
    
    func hide() {
        pendingHideWorkItem?.cancel()

        // Trigger the hide animation first
        visibilityManager.isVisible = false
        visibilityManager.shouldDismiss = true
        
        // Wait for animation to complete before actually hiding the window
        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.pendingHideWorkItem = nil
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func registerMoveObserverIfNeeded(for panel: NSPanel) {
        guard moveObserver == nil else { return }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.saveOrigin(panel.frame.origin)
        }
    }

    private func initialOrigin(for panel: NSPanel) -> NSPoint {
        if let saved = loadSavedOrigin() {
            return clampedOrigin(saved, for: panel)
        }
        return defaultOrigin(for: panel)
    }

    private func moveToDefaultPosition(_ panel: NSPanel?, animated: Bool) {
        guard let panel else { return }
        let target = defaultOrigin(for: panel)

        if !animated {
            pendingResetWorkItem?.cancel()
            pendingResetWorkItem = nil
            panel.setFrameOrigin(target)
            return
        }

        let current = panel.frame.origin
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let distance = hypot(deltaX, deltaY)

        // Avoid animation churn when we are effectively already at the default spot.
        guard distance > 1 else {
            panel.setFrameOrigin(target)
            return
        }

        pendingResetWorkItem?.cancel()
        // Overshoot in the same direction as travel so the return path stays natural.
        let unitX = deltaX / distance
        let unitY = deltaY / distance
        let overshootDistance = min(12, max(6, distance * 0.12))
        let overshoot = NSPoint(
            x: target.x + unitX * overshootDistance,
            y: target.y + unitY * overshootDistance
        )
        let overshootFrame = NSRect(origin: overshoot, size: panel.frame.size)
        let targetFrame = NSRect(origin: target, size: panel.frame.size)

        // Step 1: quick "buzz" overshoot toward the default anchor.
        panel.setFrame(overshootFrame, display: true, animate: true)

        // Step 2: settle back to the exact default location.
        let settleWorkItem = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            panel.setFrame(targetFrame, display: true, animate: true)
        }
        pendingResetWorkItem = settleWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: settleWorkItem)
    }

    private func defaultOrigin(for panel: NSPanel) -> NSPoint {
        let screen = panel.screen ?? NSScreen.main
        guard let screen else {
            return panel.frame.origin
        }

        let rect = screen.visibleFrame
        return NSPoint(
            x: rect.midX - (panel.frame.width / 2),
            y: rect.minY + 50
        )
    }

    private func clampedOrigin(_ origin: NSPoint, for panel: NSPanel) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let maxX = visible.maxX - panel.frame.width
        let maxY = visible.maxY - panel.frame.height
        return NSPoint(
            x: min(max(origin.x, visible.minX), maxX),
            y: min(max(origin.y, visible.minY), maxY)
        )
    }

    private func saveOrigin(_ origin: NSPoint) {
        UserDefaults.standard.set([origin.x, origin.y], forKey: UserDefaultsKeys.recordingOverlayOrigin)
    }

    private func loadSavedOrigin() -> NSPoint? {
        if let numbers = UserDefaults.standard.array(forKey: UserDefaultsKeys.recordingOverlayOrigin) as? [NSNumber],
           numbers.count == 2 {
            return NSPoint(x: numbers[0].doubleValue, y: numbers[1].doubleValue)
        }

        if let doubles = UserDefaults.standard.array(forKey: UserDefaultsKeys.recordingOverlayOrigin) as? [Double],
           doubles.count == 2 {
            return NSPoint(x: doubles[0], y: doubles[1])
        }

        return nil
    }
}

private final class OverlayPanel: NSPanel {
    var onDoubleClick: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.sendEvent(event)
    }
}
