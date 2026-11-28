import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// French's held-key popups as Apple's French (France) keyboard drew them on a 440-point-wide
/// iPhone on iOS 27.2, left to right, laid out over the keys where that phone drew them
/// (`apple-languages/popups-observed.json`, `key-frames/fr_FR-portrait-*.frames.json`).
final class FrenchHeldKeyCharactersTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 440, height: 245)
    /// A popup cell is the key's width less the gap between keys, plus the keyboard's cell
    /// allowance, as the KeyVox keyboard sizes it (`KeyboardStyle`).
    private func metrics(keyWidth: CGFloat) -> HeldKeyPopupLayout.Metrics {
        HeldKeyPopupLayout.Metrics(cellWidth: keyWidth - 2.1, cellHeight: 47, padding: 10.2, gapAboveKey: 4.4, closingDistance: 87.8)
    }

    func testPopupsDrawAsApplesFrenchKeyboardDrewThem() throws {
        let list = try HeldKeyCharacters.bundled(for: .french)
        // Key: (the key's left edge and width in the phone's touch frames, Apple's popup).
        let drawn: [String: (x: CGFloat, width: CGFloat, popup: String)] = [
            "a": (4.67, 43, "a à â æ á ä ã å ā ª"),
            "e": (91, 43.33, "e é è ê ë ę ė ē"),
            "o": (351, 43.33, "º ō ø õ ó ò œ ô o ö"),
            "u": (264.33, 43.33, "ū ú ü ù û u"),
            "i": (307.67, 43.33, "ī į í ì ï î i"),
            "c": (156, 43.33, "c ç ć č"),
            "n": (286, 43.33, "ń ñ n"),
            "y": (221, 43.33, "ÿ y"),
            "´": (329.33, 43.33, "¨ ˆ ˋ ´"),
            "0": (394.33, 43.33, "° 0"),
            "-": (4.67, 43, "- – — •"),
            "/": (47.67, 43.33, "/ \\"),
            "$": (264.33, 43.33, "₽ ¥ € $ ¢ £ ₩"),
            "&": (307.67, 43.33, "& §"),
            "\"": (394.33, 43.33, "„ “ ” « » \""),
            ".": (69.33, 60.67, "… . ·"),
            "?": (190.67, 60.67, "? ¿"),
            "!": (251.33, 60.67, "! ¡"),
            "’": (312, 60.67, "` ‘ ’ '"),
            "%": (221, 43.33, "% ‰"),
            "=": (394.33, 43.33, "≈ ≠ ="),
        ]
        for (key, apple) in drawn {
            let offer = try XCTUnwrap(list.offer(forKey: key), key)
            let layout = HeldKeyPopupLayout(
                offer: offer,
                keyFrame: CGRect(x: apple.x, y: 119, width: apple.width, height: 56),
                bounds: bounds,
                metrics: metrics(keyWidth: apple.width)
            )
            XCTAssertEqual(layout.rows.flatMap { $0.map(\.character) }.joined(separator: " "), apple.popup, key)
        }
    }

    func testCapitalsOfferWhatTheirLettersOffer() throws {
        let list = try HeldKeyCharacters.bundled(for: .french)
        for letter in "aceinouy" {
            let lower = try XCTUnwrap(list.offer(forKey: String(letter)))
            let upper = try XCTUnwrap(list.offer(forKey: letter.uppercased()))
            XCTAssertEqual(upper.characters, lower.characters.map { $0.uppercased() }, String(letter))
            XCTAssertEqual(upper.direction, lower.direction)
        }
    }
}
