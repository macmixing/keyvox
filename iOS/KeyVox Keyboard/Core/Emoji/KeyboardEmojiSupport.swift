import CoreText
import Foundation

/// Asks the system's emoji font whether it draws an emoji as one picture, so the keyboard offers
/// only the emoji this phone shows. The font draws an emoji newer than the system as its parts,
/// such as the people of a family, and one it has no picture for in another font.
enum KeyboardEmojiSupport {
    private static let emojiFontName = "AppleColorEmoji"
    private static let font = CTFontCreateWithName(emojiFontName as CFString, 32, nil)

    static func canDraw(_ emoji: String) -> Bool {
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: emoji,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        ))
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun],
              runs.count == 1,
              let run = runs.first,
              usesEmojiFont(run) else {
            return false
        }
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var advances = [CGSize](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetAdvances(run, CFRange(location: 0, length: count), &advances)
        // Joiners and variation selectors take no room; only drawn pictures count.
        let pictures = zip(glyphs, advances).filter { glyph, advance in glyph != 0 && advance.width > 0 }
        return pictures.count == 1
    }

    private static func usesEmojiFont(_ run: CTRun) -> Bool {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard let value = attributes[kCTFontAttributeName as String] else { return false }
        let runFont = value as! CTFont
        return CTFontCopyPostScriptName(runFont) as String == emojiFontName
    }
}
