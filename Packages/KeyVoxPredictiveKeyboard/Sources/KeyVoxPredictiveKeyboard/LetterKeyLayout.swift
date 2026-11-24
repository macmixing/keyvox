import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One of Apple's letter layouts, such as `QWERTY` or `AZERTY-French`: the letter rows a keyboard
/// draws, and where the engine aims touches at them before the keyboard reports its real key frames.
/// Read from `PredictiveData/letter_layouts/<identifier>.json`, which holds the rows of Apple's
/// iPhone keyboard for that layout.
public struct LetterKeyLayout: Sendable {
    /// Apple's name for the layout, such as `QWERTZ-German`.
    public let identifier: String
    /// The letter rows, top to bottom; every row is `width` letter keys wide.
    public let rows: [LetterKeyRow]
    /// How wide each row is, in letter keys.
    public let width: Double
    /// Every letter key on a grid of 100-point keys, rows top to bottom.
    public let defaultGeometry: [PredictionKeyGeometry]

    /// The bundled layout named `identifier`.
    public static func bundled(identifier: String) throws -> LetterKeyLayout {
        let layout: LetterKeyLayout
        do {
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url(identifier: identifier)))
            layout = try LetterKeyLayout(identifier: file.identifier, rows: file.rows)
        } catch let error as PredictiveKeyboardError {
            throw error
        } catch {
            throw PredictiveKeyboardError.invalidLetterLayout(identifier)
        }
        guard layout.identifier == identifier else {
            throw PredictiveKeyboardError.invalidLetterLayout(identifier)
        }
        return layout
    }

    private init(identifier: String, rows: [LetterKeyRow]) throws {
        // Apple's rows are equally wide; their widths are stored to two decimals, so they add
        // up to the same width only to within rounding.
        guard let firstRow = rows.first,
              rows.allSatisfy({ abs($0.width - firstRow.width) < 1 / Self.widthPrecision }) else {
            throw PredictiveKeyboardError.invalidLetterLayout(identifier)
        }
        self.identifier = identifier
        self.rows = rows
        width = (firstRow.width * Self.widthPrecision).rounded() / Self.widthPrecision
        defaultGeometry = rows.enumerated().flatMap { rowIndex, row in
            var x = 0.0
            return row.items.compactMap { item -> PredictionKeyGeometry? in
                defer { x += item.width }
                guard case let .character(text) = item,
                      let character = text.first,
                      character.isLetter else { return nil }
                return PredictionKeyGeometry(
                    character: character,
                    frame: CGRect(x: x * 100, y: Double(rowIndex) * 100, width: 100, height: 100)
                )
            }
        }
    }

    /// Steps per letter key that row widths are rounded to.
    private static let widthPrecision = 1_000_000.0

    private static func url(identifier: String) throws -> URL {
        let name = "PredictiveData/letter_layouts/\(identifier).json"
        guard let data = KeyVoxPredictiveKeyboardResources.bundle.url(forResource: "PredictiveData", withExtension: nil) else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData")
        }
        let url = data
            .appendingPathComponent("letter_layouts", isDirectory: true)
            .appendingPathComponent("\(identifier).json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PredictiveKeyboardError.missingArtifact(name)
        }
        return url
    }

    private struct File: Decodable {
        let identifier: String
        let rows: [LetterKeyRow]
    }
}
