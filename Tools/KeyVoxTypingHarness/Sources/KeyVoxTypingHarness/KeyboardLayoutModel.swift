import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Key frames for the KeyVox portrait letter page, in key-grid points.
///
/// Sizes follow the KeyVox keyboard grid: 6 pt between keys, 8 pt between rows,
/// 48 pt key height, ten top-row keys filling the grid width, shift and delete flanking
/// the bottom letter row, and 123, space, and return below.
struct KeyboardLayoutModel {
    enum Key: Equatable {
        case letter(Character)
        case shift
        case delete
        case numbers
        case space
        case returnKey
    }

    private static let rows: [(letters: String, offsetInKeyPitches: Double)] = [
        ("qwertyuiop", 0),
        ("asdfghjkl", 0.5),
        ("zxcvbnm", 1.5),
    ]
    private static let keySpacing = 6.0
    private static let rowSpacing = 8.0
    private static let keyHeight = 48.0

    let keyFrames: [Character: CGRect]
    /// Every key on the page, letters included.
    let allKeys: [(key: Key, frame: CGRect)]
    let keyboardSize: CGSize
    /// Distance between neighboring key centers across a row and between rows.
    let keyPitch: CGSize

    init(gridWidth: Double = 394) {
        let keyWidth = (gridWidth - Self.keySpacing * 9) / 10
        let keyPitch = keyWidth + Self.keySpacing
        let rowPitch = Self.keyHeight + Self.rowSpacing
        self.keyPitch = CGSize(width: keyPitch, height: rowPitch)
        var frames: [Character: CGRect] = [:]
        for (rowIndex, row) in Self.rows.enumerated() {
            let y = Double(rowIndex) * rowPitch
            for (columnIndex, letter) in row.letters.enumerated() {
                let x = (row.offsetInKeyPitches + Double(columnIndex)) * keyPitch
                frames[letter] = CGRect(x: x, y: y, width: keyWidth, height: Self.keyHeight)
            }
        }
        keyFrames = frames

        let shiftRowY = 2 * rowPitch
        let specialWidth = keyWidth * 1.5 + Self.keySpacing * 0.5
        let bottomRowY = 3 * rowPitch
        let sideWidth = keyWidth * 2.5 + Self.keySpacing * 1.5
        let spaceWidth = gridWidth - sideWidth * 2 - Self.keySpacing * 2
        allKeys = frames.map { (Key.letter($0.key), $0.value) } + [
            (.shift, CGRect(x: 0, y: shiftRowY, width: specialWidth, height: Self.keyHeight)),
            (.delete, CGRect(x: gridWidth - specialWidth, y: shiftRowY, width: specialWidth, height: Self.keyHeight)),
            (.numbers, CGRect(x: 0, y: bottomRowY, width: sideWidth, height: Self.keyHeight)),
            (.space, CGRect(x: sideWidth + Self.keySpacing, y: bottomRowY, width: spaceWidth, height: Self.keyHeight)),
            (.returnKey, CGRect(x: gridWidth - sideWidth, y: bottomRowY, width: sideWidth, height: Self.keyHeight)),
        ]

        let gridRowCount = Double(Self.rows.count + 1)
        keyboardSize = CGSize(
            width: gridWidth,
            height: gridRowCount * Self.keyHeight + (gridRowCount - 1) * Self.rowSpacing
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

    /// The letter key a touch lands on, ignoring the other keys: the nearest letter key
    /// rectangle, so gaps resolve to a neighbor.
    func letter(at point: CGPoint) -> Character {
        keyFrames.min { left, right in
            Self.distance(from: point, to: left.value) < Self.distance(from: point, to: right.value)
        }!.key
    }

    /// The key a touch lands on as the keyboard resolves it: the nearest key of any kind
    /// within the keyboard's touch margin (14 pt), or nil when the tap misses the keyboard.
    func key(at point: CGPoint) -> (key: Key, frame: CGRect)? {
        let nearest = allKeys.min { left, right in
            Self.distance(from: point, to: left.frame) < Self.distance(from: point, to: right.frame)
        }!
        return Self.distance(from: point, to: nearest.frame) <= 14 ? nearest : nil
    }

    static func distance(from point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
