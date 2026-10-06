import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Letter key centers and the key pitch of the keyboard currently on screen, so touch
/// distances can be measured in keys rather than points.
public struct KeyCenterMap: Sendable {
    private let centers: [Character: CGPoint]
    private let frames: [Character: CGRect]
    /// Typical distance between neighboring key centers across a row and between rows.
    public let pitch: CGSize

    public init(geometry: [PredictionKeyGeometry]) {
        var centers: [Character: CGPoint] = [:]
        var frames: [Character: CGRect] = [:]
        for key in geometry {
            let letter = Character(key.character.lowercased())
            centers[letter] = CGPoint(x: key.frame.midX, y: key.frame.midY)
            frames[letter] = key.frame
        }
        self.centers = centers
        self.frames = frames
        pitch = Self.pitch(of: centers)
    }

    public func center(of letter: Character) -> CGPoint? {
        centers[Character(letter.lowercased())]
    }

    /// The letter keys within `maximumDistance` key pitches of a touch, with how far outside
    /// each key the touch is (zero when it is on the key).
    public func letters(
        near point: CGPoint,
        within maximumDistance: Double
    ) -> [(letter: Character, distance: Double)] {
        frames.compactMap { letter, frame in
            let dx = Double(max(frame.minX - point.x, 0, point.x - frame.maxX)) / Double(pitch.width)
            let dy = Double(max(frame.minY - point.y, 0, point.y - frame.maxY)) / Double(pitch.height)
            let distance = (dx * dx + dy * dy).squareRoot()
            return distance <= maximumDistance ? (letter, distance) : nil
        }
    }

    /// The median horizontal gap between keys sharing a row and the median vertical gap
    /// between rows, which stays correct for any key widths the host lays out.
    private static func pitch(of centers: [Character: CGPoint]) -> CGSize {
        let rows = Dictionary(grouping: centers.values) { ($0.y * 2).rounded() / 2 }
        let horizontal = rows.values.flatMap { row -> [Double] in
            let xs = row.map(\.x).sorted()
            return zip(xs, xs.dropFirst()).map { Double($1 - $0) }
        }
        let rowYs = rows.keys.sorted()
        let vertical = zip(rowYs, rowYs.dropFirst()).map { Double($1 - $0) }
        return CGSize(width: median(horizontal) ?? 1, height: median(vertical) ?? 1)
    }

    private static func median(_ values: [Double]) -> Double? {
        let positive = values.filter { $0 > 0 }.sorted()
        guard positive.isEmpty == false else { return nil }
        return positive[positive.count / 2]
    }
}
