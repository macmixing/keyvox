import AppKit
import SwiftUI

extension View {
    @ViewBuilder
    func keyVoxWindowDragGesture(allowsActivationEvents: Bool) -> some View {
        if #available(macOS 15.0, *) {
            gesture(WindowDragGesture())
                .allowsWindowActivationEvents(allowsActivationEvents)
        } else {
            background(LegacyWindowDragRegion())
        }
    }
}

private struct LegacyWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> LegacyWindowDragRegionView {
        LegacyWindowDragRegionView()
    }

    func updateNSView(_ nsView: LegacyWindowDragRegionView, context: Context) {}
}

private final class LegacyWindowDragRegionView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
