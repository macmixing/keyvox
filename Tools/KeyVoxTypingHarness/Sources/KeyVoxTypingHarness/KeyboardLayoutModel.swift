import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Letter-key frames for a portrait iPhone QWERTY grid, in points.
///
/// Sizes follow the KeyVox keyboard grid: 6 pt between keys, 8 pt between rows,
/// 48 pt key height, and ten top-row keys filling the grid width.
struct KeyboardLayoutModel {
    private static let rows: [(letters: String, offsetInKeyPitches: Double)] = [
        ("qwertyuiop", 0),
        ("asdfghjkl", 0.5),
        ("zxcvbnm", 1.5),
    ]
    private static let keySpacing = 6.0
    private static let rowSpacing = 8.0
    private static let keyHeight = 48.0

    let keyFrames: [Character: CGRect]
    let keyboardSize: CGSize

    init(gridWidth: Double = 394) {
        let keyWidth = (gridWidth - Self.keySpacing * 9) / 10
        let keyPitch = keyWidth + Self.keySpacing
        var frames: [Character: CGRect] = [:]
        for (rowIndex, row) in Self.rows.enumerated() {
            let y = Double(rowIndex) * (Self.keyHeight + Self.rowSpacing)
            for (columnIndex, letter) in row.letters.enumerated() {
                let x = (row.offsetInKeyPitches + Double(columnIndex)) * keyPitch
                frames[letter] = CGRect(x: x, y: y, width: keyWidth, height: Self.keyHeight)
            }
        }
        keyFrames = frames
        keyboardSize = CGSize(
            width: gridWidth,
            height: Double(Self.rows.count) * Self.keyHeight
                + Double(Self.rows.count - 1) * Self.rowSpacing
        )
    }

    var predictionGeometry: [PredictionKeyGeometry] {
        keyFrames
            .sorted { $0.key < $1.key }
            .map { PredictionKeyGeometry(character: $0.key, frame: $0.value) }
    }

    func center(of letter: Character) -> CGPoint? {
        guard let frame = keyFrames[letter] else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// The key a touch lands on: the nearest key rectangle, so gaps resolve to a neighbor.
    func letter(at point: CGPoint) -> Character {
        keyFrames.min { left, right in
            Self.distance(from: point, to: left.value) < Self.distance(from: point, to: right.value)
        }!.key
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
