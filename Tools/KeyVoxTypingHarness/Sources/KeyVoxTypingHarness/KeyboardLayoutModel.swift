import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Key frames for the KeyVox portrait letter page of a typing language, in key-grid points.
///
/// Sizes follow the KeyVox keyboard grid: 6 pt between keys, 8 pt between rows, 48 pt key
/// height, the language's letter rows (`TypingLanguage.letterLayout`) filling the grid width
/// with every item at its width in letter keys, shift and delete at theirs (across the padding
/// beside them where the layout draws them so), and 123, space, and return below. Only the rows'
/// letters are letter keys, as on the keyboard; the language's accent key, drawn in a row where
/// its layout has one, is a key of its own. For English's
/// QWERTY these are the frames the harness always used: ten top-row keys, the second row half a
/// key in, and the third a key and a half in, between keys one and a half wide.
struct KeyboardLayoutModel {
    enum Key: Equatable {
        case letter(Character)
        /// The language's accent key (`TypingLanguage.accentKey`).
        case accentKey
        case shift
        case delete
        case numbers
        case space
        case returnKey
    }

    private static let keySpacing = 6.0
    private static let rowSpacing = 8.0
    private static let keyHeight = 48.0

    /// The letter keys' frames: the rows' letters alone, as the keyboard hands the engine.
    let keyFrames: [Character: CGRect]
    /// Letters no key types, each with the key whose held popup offers it, such as German "ß" on "s".
    let popupLetters: [Character: Character]
    /// Every key on the page, letters included.
    let allKeys: [(key: Key, frame: CGRect)]
    let keyboardSize: CGSize
    /// Distance between neighboring key centers across a row and between rows.
    let keyPitch: CGSize

    init(language: TypingLanguage, gridWidth: Double = 394) {
        let layout = language.letterLayout
        let keyPitch = (gridWidth + Self.keySpacing) / layout.width
        let keyWidth = keyPitch - Self.keySpacing
        let rowPitch = Self.keyHeight + Self.rowSpacing
        self.keyPitch = CGSize(width: keyPitch, height: rowPitch)
        var frames: [Character: CGRect] = [:]
        var controls: [(Key, CGRect)] = []
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
                    let frame = CGRect(x: x * keyPitch, y: y, width: keyWidth, height: Self.keyHeight)
                    for character in text {
                        if character.isLetter {
                            frames[character] = frame
                        } else if language.accentKey?.character == String(character) {
                            controls.append((.accentKey, frame))
                        } else {
                            preconditionFailure("\(layout.identifier) draws \(character), no letter and no accent key of \(language.identifier)")
                        }
                    }
                case let .shift(width):
                    let units = width + padding(index + 1)
                    controls.append((.shift, CGRect(x: x * keyPitch, y: y, width: units * keyPitch - Self.keySpacing, height: Self.keyHeight)))
                case let .delete(width):
                    let fill = padding(index - 1)
                    controls.append((.delete, CGRect(x: (x - fill) * keyPitch, y: y, width: (width + fill) * keyPitch - Self.keySpacing, height: Self.keyHeight)))
                case .padding:
                    break
                }
            }
        }
        keyFrames = frames

        var popupLetters: [Character: Character] = [:]
        if let held = try? HeldKeyCharacters.bundled(for: language) {
            for key in frames.keys.sorted() {
                for character in held.offer(forKey: String(key))?.characters ?? [] {
                    guard character.count == 1, let letter = character.first, letter.isLetter,
                          frames[letter] == nil, popupLetters[letter] == nil else { continue }
                    popupLetters[letter] = key
                }
            }
        }
        self.popupLetters = popupLetters

        let bottomRowY = Double(layout.rows.count) * rowPitch
        let sideWidth = keyWidth * 2.5 + Self.keySpacing * 1.5
        let spaceWidth = gridWidth - sideWidth * 2 - Self.keySpacing * 2
        allKeys = frames.map { (Key.letter($0.key), $0.value) } + controls + [
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

    /// Whether `letter` can be typed: it has a key, or a key's held popup offers it.
    func types(_ letter: Character) -> Bool {
        keyFrames[letter] != nil || popupLetters[letter] != nil
    }

    var predictionGeometry: [PredictionKeyGeometry] {
        keyFrames
            .sorted { $0.key < $1.key }
            .map { PredictionKeyGeometry(character: $0.key, frame: $0.value) }
    }

    /// The center of the key that types `letter`, or of the key whose popup offers it.
    func center(of letter: Character) -> CGPoint? {
        guard let frame = keyFrames[letter] ?? popupLetters[letter].flatMap({ keyFrames[$0] }) else { return nil }
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
