import SwiftUI

struct RecordingOverlay: View {
    @ObservedObject var recorder: AudioRecorder
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Circle()
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
                .shadow(radius: 10)
                .frame(width: 50, height: 50)
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    BarView(value: Double(recorder.audioLevel), index: index)
                }
            }
        }
    }
}

struct BarView: View {
    var value: Double
    var index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.8)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0) // The "Glow"
            .frame(width: 4, height: height)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: value)
    }
    
    var height: CGFloat {
        // Create a "wave" effect from a single value
        let multipliers: [Double] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let minHeight: CGFloat = 6
        let maxHeight: CGFloat = 30
        
        // Center the wave peak
        let dynamicHeight = CGFloat(value * multipliers[index]) * maxHeight
        return max(minHeight, dynamicHeight)
    }
}

class OverlayManager {
    static let shared = OverlayManager()
    private var window: NSPanel?
    
    func show(recorder: AudioRecorder) {
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
            
            let contentView = NSHostingView(rootView: RecordingOverlay(recorder: recorder))
            panel.contentView = contentView
            
            // Center on bottom of screen
            if let screen = NSScreen.main {
                let rect = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: rect.midX - 40, y: rect.minY + 50))
            }
            
            window = panel
        }
        
        // Always update the content view to ensure binding is fresh
        window?.contentView = NSHostingView(rootView: RecordingOverlay(recorder: recorder))
        window?.orderFrontRegardless()
    }
    
    func hide() {
        window?.orderOut(nil)
    }
}
