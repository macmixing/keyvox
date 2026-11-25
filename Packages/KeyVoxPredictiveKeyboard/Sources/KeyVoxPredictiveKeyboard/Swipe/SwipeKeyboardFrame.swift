import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Maps the keyboard on screen into the frame the swipe model reads: the typing language's
/// letter rows spanning 0 to 1 across and down, as its default layout lays them out
/// (`LetterKeyLayout`).
///
/// Each axis is the least-squares fit of the live letter key centers onto the default layout's,
/// so any key widths, gaps, and row offsets the host lays out land where the model expects
/// them, and the key centers handed to the model are the live keys' own.
struct SwipeKeyboardFrame: Sendable {
    private let scaleX: Double
    private let offsetX: Double
    private let scaleY: Double
    private let offsetY: Double
    /// Each model key's center in the model's frame, in the model's key order.
    let keyCenters: [(x: Float, y: Float)]

    /// Nil when the live keys lack a letter of the model's keys or cannot span the frame.
    init?(keys: KeyCenterMap, layout: LetterKeyLayout, letters: String) {
        let reference = layout.defaultGeometry
        let width = reference.map { Double($0.frame.maxX) }.max() ?? 0
        let height = reference.map { Double($0.frame.maxY) }.max() ?? 0
        guard width > 0, height > 0 else { return nil }
        var referenceCenters: [Character: (x: Double, y: Double)] = [:]
        for key in reference {
            referenceCenters[Character(key.character.lowercased())] = (
                Double(key.frame.midX) / width,
                Double(key.frame.midY) / height
            )
        }
        var pairs: [(live: CGPoint, reference: (x: Double, y: Double))] = []
        for letter in letters {
            guard let live = keys.center(of: letter), let target = referenceCenters[letter] else { return nil }
            pairs.append((live, target))
        }
        guard let x = Self.fit(pairs.map { (Double($0.live.x), $0.reference.x) }),
              let y = Self.fit(pairs.map { (Double($0.live.y), $0.reference.y) }) else {
            return nil
        }
        scaleX = x.scale
        offsetX = x.offset
        scaleY = y.scale
        offsetY = y.offset
        keyCenters = pairs.map {
            (Float(x.scale * Double($0.live.x) + x.offset), Float(y.scale * Double($0.live.y) + y.offset))
        }
    }

    /// `point`, in key frame coordinates, in the model's frame.
    func normalized(_ point: CGPoint) -> (x: Double, y: Double) {
        (scaleX * Double(point.x) + offsetX, scaleY * Double(point.y) + offsetY)
    }

    /// The scale and offset that best map `pairs`' first values onto their second.
    private static func fit(_ pairs: [(Double, Double)]) -> (scale: Double, offset: Double)? {
        let count = Double(pairs.count)
        guard count > 1 else { return nil }
        let meanFrom = pairs.map(\.0).reduce(0, +) / count
        let meanTo = pairs.map(\.1).reduce(0, +) / count
        let spread = pairs.map { ($0.0 - meanFrom) * ($0.0 - meanFrom) }.reduce(0, +)
        guard spread > 0 else { return nil }
        let scale = pairs.map { ($0.0 - meanFrom) * ($0.1 - meanTo) }.reduce(0, +) / spread
        return (scale, meanTo - scale * meanFrom)
    }
}
