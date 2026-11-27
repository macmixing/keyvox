import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How well the point a swipe lands on fits each key as the first key of the word swiped, when
/// the swipe is drawn with care: it lands and lifts well inside keys.
///
/// It ranks only words whose key paths differ in their first key alone, which the rest of the
/// swipe cannot tell apart: they trade places among themselves (`SwipeWordDecoder`), so a swipe
/// from one key to another gives the word on those keys rather than a likelier word that starts a
/// key over, and no word moves against a word on other keys.
///
/// Among them a word loses up to `weight` as the landing leaves its first key behind: nothing while the
/// landing is within `reach` key pitches of the key's center, all of it beyond, rising over about
/// `softness` to either side. `reach` is past the key's own edge, so of two words starting on
/// neighboring keys the one whose key the finger landed on wins only when the landing is not
/// toward the other key; a landing between the two leaves them to the rest of their scores. The
/// loss counts in full only when the swipe both lands and lifts within `careReach` of a key's
/// center, and not at all when either end is well outside: a swipe loose about its ends says
/// little by where it starts.
///
/// On swipe.futo.org's validation swipes that land on a key beside the first key of a likelier
/// word with the same letters after, the word on the landing key is the one meant in 81% to 97%
/// of those landing at the key's center or away from the other key, 36% of those 0.1 to 0.3 key
/// pitches toward it, and 6% of those beyond. Of the swipes that land clear of the other key yet
/// mean its word, over half lift more than 0.35 key pitches from every key's center.
enum SwipeLandingKey {
    struct Settings: Decodable, Sendable, Equatable {
        /// What a word loses, in its score (`SwipeCandidateScoring`), when the swipe lands far
        /// from its first key.
        let weight: Double
        /// How far from a key's center, in key pitches, a landing costs half of `weight`.
        let reach: Double
        /// How far from the nearest key's center, in key pitches, a landing or a lift halves the loss.
        let careReach: Double
        /// Over how many key pitches around `reach` and `careReach` the loss rises and falls.
        let softness: Double
    }

    /// For each of `letters`' keys, in their order, what a word starting on it loses for where
    /// `path` lands and lifts on the keys `keys` lays out, distances counted in the key pitch
    /// across and the row pitch down; nil when the path is empty or the keys lack one of the letters.
    static func losses(path: [SwipeTouchSample], keys: KeyCenterMap, letters: String, settings: Settings) -> [Double]? {
        let ordered = path.enumerated().sorted {
            $0.element.timestamp != $1.element.timestamp
                ? $0.element.timestamp < $1.element.timestamp
                : $0.offset < $1.offset
        }
        guard let landing = ordered.first?.element.location, let lift = ordered.last?.element.location else { return nil }
        var landingDistances: [Double] = []
        var liftDistance = Double.infinity
        for letter in letters {
            guard let center = keys.center(of: letter) else { return nil }
            landingDistances.append(distance(landing, center, pitch: keys.pitch))
            liftDistance = min(liftDistance, distance(lift, center, pitch: keys.pitch))
        }
        let care = (1 - rise(landingDistances.min() ?? .infinity, around: settings.careReach, softness: settings.softness))
            * (1 - rise(liftDistance, around: settings.careReach, softness: settings.softness))
        return landingDistances.map { settings.weight * care * rise($0, around: settings.reach, softness: settings.softness) }
    }

    /// From 0 well below `middle` to 1 well above it, half at it.
    private static func rise(_ value: Double, around middle: Double, softness: Double) -> Double {
        1 / (1 + exp(-(value - middle) / softness))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint, pitch: CGSize) -> Double {
        let dx = Double(a.x - b.x) / Double(pitch.width)
        let dy = Double(a.y - b.y) / Double(pitch.height)
        return (dx * dx + dy * dy).squareRoot()
    }
}
