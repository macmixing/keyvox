import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Key frames for the KeyVox portrait letter page of a typing language, in key-grid points.
///
/// Sizes follow the KeyVox keyboard grid: 6 pt between keys, 8 pt between rows, 48 pt key
/// height, the language's letter rows (`TypingLanguage.letterLayout`) filling the grid width
/// with every item at its width in letter keys, shift and delete at theirs (across the padding
/// beside them where the layout draws them so), and 123, space, and return below. For QWERTY
/// these are ten top-row keys, the second row half a key in, and the third a key and a half in,
/// between keys one and a half wide.
public struct KeyboardLayoutModel {
    public enum Key: Equatable {
        case letter(Character)
        case shift
        case delete
        case numbers
        case space
        case returnKey
    }

    private static let keySpacing = 6.0
    private static let rowSpacing = 8.0
    private static let keyHeight = 48.0
    /// How far outside a key a touch still lands on it, as the keyboard resolves touches.
    private static let touchMargin = 14.0

    public let keyFrames: [Character: CGRect]
    /// Every key on the page, letters first in letter order, so a touch as near one key as
    /// another always lands on the same one.
    public let allKeys: [(key: Key, frame: CGRect)]
    public let keyboardSize: CGSize
    /// Distance between neighboring key centers across a row and between rows.
    public let keyPitch: CGSize

    public init(language: TypingLanguage, gridWidth: Double = 394) {
        let layout = language.letterLayout
        let keyPitch = (gridWidth + Self.keySpacing) / layout.width
        let keyWidth = keyPitch - Self.keySpacing
        let rowPitch = Self.keyHeight + Self.rowSpacing
        self.keyPitch = CGSize(width: keyPitch, height: rowPitch)
        var frames: [Character: CGRect] = [:]
        var controls: [(key: Key, frame: CGRect)] = []
        for (rowIndex, row) in layout.rows.enumerated() {
            let y = Double(rowIndex) * rowPitch
            var x = 0.0
            for (index, item) in row.items.enumerated() {
                defer { x += item.width }
                let padding = { (neighbor: Int) -> Double in
                    guard layout.shiftAndDeleteFillPadding, row.items.indices.contains(neighbor),
                          case let .padding(width) = row.items[neighbor] else { return 0 }
                    return width
                }
                switch item {
                case let .character(text):
                    for letter in text {
                        frames[letter] = CGRect(x: x * keyPitch, y: y, width: keyWidth, height: Self.keyHeight)
                    }
                case let .shift(width):
                    let units = width + padding(index + 1)
                    controls.append((.shift, CGRect(
                        x: x * keyPitch, y: y, width: units * keyPitch - Self.keySpacing, height: Self.keyHeight
                    )))
                case let .delete(width):
                    let fill = padding(index - 1)
                    controls.append((.delete, CGRect(
                        x: (x - fill) * keyPitch, y: y, width: (width + fill) * keyPitch - Self.keySpacing,
                        height: Self.keyHeight
                    )))
                case .padding:
                    break
                }
            }
        }
        keyFrames = frames

        let bottomRowY = Double(layout.rows.count) * rowPitch
        let sideWidth = keyWidth * 2.5 + Self.keySpacing * 1.5
        let spaceWidth = gridWidth - sideWidth * 2 - Self.keySpacing * 2
        allKeys = frames.sorted { $0.key < $1.key }.map { (Key.letter($0.key), $0.value) } + controls + [
            (.numbers, CGRect(x: 0, y: bottomRowY, width: sideWidth, height: Self.keyHeight)),
            (.space, CGRect(x: sideWidth + Self.keySpacing, y: bottomRowY, width: spaceWidth, height: Self.keyHeight)),
            (.returnKey, CGRect(x: gridWidth - sideWidth, y: bottomRowY, width: sideWidth, height: Self.keyHeight)),
        ]

        let gridRowCount = Double(layout.rows.count + 1)
        keyboardSize = CGSize(
            width: gridWidth,
            height: gridRowCount * Self.keyHeight + (gridRowCount - 1) * Self.rowSpacing
        )
    }

    public var predictionGeometry: [PredictionKeyGeometry] {
        keyFrames
            .sorted { $0.key < $1.key }
            .map { PredictionKeyGeometry(character: $0.key, frame: $0.value) }
    }

    public func center(of letter: Character) -> CGPoint? {
        guard let frame = keyFrames[letter] else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// The letter key a touch lands on, ignoring the other keys: the nearest letter key
    /// rectangle, so gaps resolve to a neighbor.
    public func letter(at point: CGPoint) -> Character {
        allKeys.compactMap { entry -> (letter: Character, frame: CGRect)? in
            guard case let .letter(letter) = entry.key else { return nil }
            return (letter, entry.frame)
        }.min { left, right in
            Self.distance(from: point, to: left.frame) < Self.distance(from: point, to: right.frame)
        }!.letter
    }

    /// The key a touch lands on as the keyboard resolves it: the nearest key of any kind
    /// within the keyboard's touch margin, or nil when the tap misses the keyboard.
    public func key(at point: CGPoint) -> (key: Key, frame: CGRect)? {
        let nearest = allKeys.min { left, right in
            Self.distance(from: point, to: left.frame) < Self.distance(from: point, to: right.frame)
        }!
        return Self.distance(from: point, to: nearest.frame) <= Self.touchMargin ? nearest : nil
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
