import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How well the point a swipe lands on fits each key as the first key of the word swiped.
///
/// It ranks only words whose key paths differ in their first key alone, which the rest of the
/// swipe cannot tell apart: they trade places among themselves (`SwipeWordDecoder`), so a swipe
/// that lands on one key gives the word on that key rather than a likelier word that starts a
/// key over, and no word moves against a word on other keys.
///
/// People land around the key they mean as a bell curve, and now and then stray: a word loses
/// the natural log of how much less likely the landing is for its first key than a landing on
/// that key's center. Between two keys side by side that favors the nearer, by more the nearer
/// the landing is to it and by nothing halfway between them, and a landing far from both says
/// no more against one than the other; the words before and the rest of the scores still weigh
/// against it. Every swipe's landing counts, wherever the swipe lifts.
///
/// The figures are swipe.futo.org's validation swipes', measured from each word's first key in
/// key pitches (the key pitch across, the row pitch down). 99.44% land within one key pitch of
/// the key's center, a bell curve spread `spread` (0.228) to each side; `strayRate` is the
/// 0.56% that land farther, counted as landing anywhere on the letter keys.
///
/// On swipe.futo.org's training and validation swipes of a rare word whose commoner neighbor
/// starts a key over, the swipes land a median 0.09 key pitches from their key's center toward
/// the other key and nine in ten within half a pitch of it, and lift a median 0.31 from their
/// last key whichever word they mean; taking the lift's miss off the landing, as if the whole
/// swipe were shifted, tells the two words apart worse than the landing alone, and the bell is
/// little wider for swipes that lift far from a key (0.26) than for those that lift on one (0.21).
enum SwipeLandingKey {
    struct Settings: Decodable, Sendable, Equatable {
        /// How far to each side of a key's center, in key pitches, landings meant for it spread:
        /// the bell curve's standard deviation.
        let spread: Double
        /// The share of landings that are strays, which land anywhere on the letter keys whatever
        /// key was meant.
        let strayRate: Double
    }

    /// For each of `letters`' keys, in their order, what a word starting on it loses, as a
    /// natural log, for where `path` lands on the keys `keys` lays out, distances counted in the
    /// key pitch across and the row pitch down; nil when the path is empty or the keys lack one
    /// of the letters.
    static func losses(path: [SwipeTouchSample], keys: KeyCenterMap, letters: String, settings: Settings) -> [Double]? {
        guard let landing = path.enumerated().min(by: {
            $0.element.timestamp != $1.element.timestamp
                ? $0.element.timestamp < $1.element.timestamp
                : $0.offset < $1.offset
        })?.element.location else { return nil }
        // How likely a stray landing is at any one point, against a meant landing at its key's
        // center: the strays spread over the letter keys, each one key pitch by one row pitch.
        let stray = settings.strayRate / (1 - settings.strayRate)
            * 2 * Double.pi * settings.spread * settings.spread / Double(letters.count)
        var losses: [Double] = []
        for letter in letters {
            guard let center = keys.center(of: letter) else { return nil }
            let offset = distance(landing, center, pitch: keys.pitch) / settings.spread
            losses.append(log(1 + stray) - log(exp(-offset * offset / 2) + stray))
        }
        return losses
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint, pitch: CGSize) -> Double {
        let dx = Double(a.x - b.x) / Double(pitch.width)
        let dy = Double(a.y - b.y) / Double(pitch.height)
        return (dx * dx + dy * dy).squareRoot()
    }
}
