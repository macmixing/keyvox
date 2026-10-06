import Foundation

enum EnglishKeyboardLayout {
    private struct KeyPosition {
        let character: Character
        let column: Double
        let row: Double
    }

    private static let keyPositions: [KeyPosition] = [
        ("qwertyuiop", 0),
        ("asdfghjkl", 0.5),
        ("zxcvbnm", 1.5),
    ].enumerated().flatMap { rowIndex, row in
        row.0.enumerated().map { columnIndex, character in
            KeyPosition(
                character: character,
                column: row.1 + Double(columnIndex),
                row: Double(rowIndex)
            )
        }
    }

    private static let positionByCharacter = Dictionary(
        uniqueKeysWithValues: keyPositions.map { ($0.character, $0) }
    )

    static let defaultGeometry = keyPositions.map { position in
        PredictionKeyGeometry(
            character: position.character,
            frame: CGRect(
                x: position.column * 100,
                y: position.row * 100,
                width: 100,
                height: 100
            )
        )
    }

    static func areNeighboring(_ left: Character, _ right: Character) -> Bool {
        let normalizedLeft = Character(left.lowercased())
        let normalizedRight = Character(right.lowercased())
        guard let leftPosition = positionByCharacter[normalizedLeft],
              let rightPosition = positionByCharacter[normalizedRight] else {
            return false
        }
        return abs(leftPosition.column - rightPosition.column) <= 1
            && abs(leftPosition.row - rightPosition.row) <= 1
    }
}
