import SwiftUI

struct RecordingOverlay: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .opacity(0.8)
            
            Text("Recording...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .shadow(radius: 10)
        )
    }
}

class OverlayManager {
    static let shared = OverlayManager()
    private var window: NSPanel?
    
    func show() {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 140, height: 40),
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
            
            let contentView = NSHostingView(rootView: RecordingOverlay())
            panel.contentView = contentView
            
            // Center on bottom of screen
            if let screen = NSScreen.main {
                let rect = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: rect.midX - 70, y: rect.minY + 50))
            }
            
            window = panel
        }
        window?.orderFrontRegardless()
    }
    
    func hide() {
        window?.orderOut(nil)
    }
}
