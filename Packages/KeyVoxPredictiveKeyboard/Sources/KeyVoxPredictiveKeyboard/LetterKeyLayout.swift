import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Where a typing language's letter keys sit relative to each other, for the engine to aim
/// touches at before the keyboard reports its real key frames.
public struct LetterKeyLayout: Sendable {
    /// Every letter key on a grid of 100-point keys, rows top to bottom.
    public let defaultGeometry: [PredictionKeyGeometry]

    init(rows: [TypingLanguageManifest.LetterRow]) {
        defaultGeometry = rows.enumerated().flatMap { rowIndex, row in
            row.letters.enumerated().map { columnIndex, character in
                PredictionKeyGeometry(
                    character: character,
                    frame: CGRect(
                        x: (row.offset + Double(columnIndex)) * 100,
                        y: Double(rowIndex) * 100,
                        width: 100,
                        height: 100
                    )
                )
            }
        }
    }
}
