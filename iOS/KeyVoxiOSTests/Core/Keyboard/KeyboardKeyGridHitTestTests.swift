import Testing
import UIKit
@testable import KeyVox_iOS

/// Which key a touch belongs to when keys overlap.
struct KeyboardKeyGridHitTestTests {
    /// Key grid widths of an open iPhone Duo, in portrait and in landscape.
    private static let widths: [CGFloat] = [647, 793]

    @Test(arguments: widths)
    @MainActor func touchOnOverlappingKeysGoesToTheKeyDrawnOnTop(width: CGFloat) throws {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 216))
        let grid = KeyboardKeyGridView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.layoutIfNeeded()
        let keyViews = grid.keyViews
        let deleteIndex = try #require(keyViews.firstIndex { $0.model.kind == .delete })
        let delete = keyViews[deleteIndex]
        let neighbor = keyViews[deleteIndex - 1]
        let deleteFrame = delete.convert(delete.bounds, to: grid)
        let neighborFrame = neighbor.convert(neighbor.bounds, to: grid)

        // Slides the key beside delete under it, past delete's middle, as delete is drawn over it.
        neighbor.transform = CGAffineTransform(translationX: deleteFrame.midX + 1 - neighborFrame.maxX, y: 0)
        let movedFrame = neighbor.convert(neighbor.bounds, to: grid)
        #expect(movedFrame.contains(CGPoint(x: deleteFrame.midX, y: deleteFrame.midY)))

        #expect(grid.keyView(at: CGPoint(x: deleteFrame.midX, y: deleteFrame.midY)) === delete)
        #expect(grid.keyView(at: CGPoint(x: movedFrame.minX + 1, y: movedFrame.midY)) === neighbor)
    }
}
