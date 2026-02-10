import SwiftUI
import Combine

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
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
                )
                .shadow(radius: 10)
                .frame(width: 50, height: 50)
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    BarView(value: Double(recorder.audioLevel), index: index, isTranscribing: isTranscribing)
                }
            }
        }
        .scaleEffect(visibilityManager.isVisible ? 1.0 : 0.3)
        .opacity(visibilityManager.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: visibilityManager.isVisible)
        .onAppear {
            withAnimation {
                visibilityManager.isVisible = true
            }
        }
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
    
    @State private var ripplePhase: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0) // The "Glow"
            .frame(width: 4, height: height)
            .animation(.linear(duration: 0.1), value: ripplePhase)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: value)
            .onAppear {
                startRippleAnimation()
            }
    }
    
    var height: CGFloat {
        let minHeight: CGFloat = 6
        let maxHeight: CGFloat = 30
        
        // Show ripples when quiet (low audio) or transcribing
        let shouldRipple = value < 0.15 || isTranscribing
        
        if shouldRipple {
            // Ripple animation: subtle wave traveling left to right
            let waveOffset = ripplePhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5 // Range: 0.0 to 1.0
            // Thin baseline (3px) with ripple going up to 12px
            return 3 + (CGFloat(rippleHeight) * 9)
        } else {
            // Normal audio-reactive animation
            let multipliers: [Double] = [0.4, 0.7, 1.0, 0.7, 0.4]
            let dynamicHeight = CGFloat(value * multipliers[index]) * maxHeight
            return max(minHeight, dynamicHeight)
        }
    }
    
    private func startRippleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ripplePhase += 0.1
            if ripplePhase > .pi * 2 {
                ripplePhase = 0
            }
        }
    }
}

class OverlayManager {
    static let shared = OverlayManager()
    private var window: NSPanel?
    private var visibilityManager = OverlayVisibilityManager()
    
    func show(recorder: AudioRecorder, isTranscribing: Bool = false) {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
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
            
            let contentView = NSHostingView(rootView: RecordingOverlay(
                recorder: recorder,
                isTranscribing: isTranscribing,
                visibilityManager: visibilityManager
            ))
            panel.contentView = contentView
            
            // Center on bottom of screen
            if let screen = NSScreen.main {
                let rect = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: rect.midX - 40, y: rect.minY + 50))
            }
            
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
        window?.orderFrontRegardless()
        
        // Trigger entrance animation after window is visible
        DispatchQueue.main.async { [weak self] in
            self?.visibilityManager.isVisible = true
        }
    }
    
    func hide() {
        // Trigger the hide animation first
        visibilityManager.isVisible = false
        visibilityManager.shouldDismiss = true
        
        // Wait for animation to complete before actually hiding the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.window?.orderOut(nil)
        }
    }
}
