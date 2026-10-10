import Foundation

/// The autocorrections the user turned down, each by the word as typed and the word it would
/// have become, remembered the way the system keyboard remembers them (measured on iOS 27 with
/// `Tools/AppleKeyboardBaseline`).
///
/// Undoing a correction right after it was made holds that correction back only for as long
/// as the keyboard keeps running. Keeping the typed word in the suggestion bar while the
/// correction waits turns it down for good: it is held back for a day, and each further time
/// for four times as long as the time before, up to 180 days. Choosing the correction again
/// lets it apply again. Words are compared the way personal words are.
public struct CorrectionRejections: Sendable, Equatable {
    /// A word as typed and the word a correction would have made it.
    public struct Pair: Hashable, Sendable {
        public let typed: String
        public let correction: String

        public init(typed: String, correction: String) {
            self.typed = PersonalVocabulary.key(typed)
            self.correction = PersonalVocabulary.key(correction)
        }
    }

    /// How often a correction was turned down for good, and when last.
    public struct Rejection: Sendable, Equatable {
        public let count: Int
        public let lastRejected: Date
    }

    /// How long one rejection holds a correction back.
    public static let firstHoldDuration: TimeInterval = 24 * 60 * 60
    /// How much longer each further rejection holds it back than the one before.
    public static let holdGrowth: Double = 4
    public static let longestHoldDuration: TimeInterval = 180 * 24 * 60 * 60
    /// Rejections kept at most; the ones turned down longest ago go first.
    public static let capacity = 1_000

    public private(set) var rejections: [Pair: Rejection]
    /// Corrections undone while the keyboard ran, which are not saved.
    private var undone: Set<Pair> = []

    public init(rejections: [Pair: Rejection] = [:]) {
        self.rejections = rejections
    }

    /// How long a correction turned down `count` times is held back after the last time.
    public static func holdDuration(afterRejections count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        return min(firstHoldDuration * pow(holdGrowth, Double(count - 1)), longestHoldDuration)
    }

    /// Whether `correction` of `typed` is held back at `date`.
    public func holdsBack(_ correction: String, of typed: String, at date: Date) -> Bool {
        let pair = Pair(typed: typed, correction: correction)
        if undone.contains(pair) { return true }
        guard let rejection = rejections[pair] else { return false }
        return date.timeIntervalSince(rejection.lastRejected) < Self.holdDuration(afterRejections: rejection.count)
    }

    /// The corrections of `typed` held back at `date`, in the form pairs are compared in.
    public func corrections(heldBackFor typed: String, at date: Date) -> Set<String> {
        let typedKey = PersonalVocabulary.key(typed)
        var held = Set(undone.filter { $0.typed == typedKey }.map(\.correction))
        for (pair, rejection) in rejections where pair.typed == typedKey
            && date.timeIntervalSince(rejection.lastRejected) < Self.holdDuration(afterRejections: rejection.count) {
            held.insert(pair.correction)
        }
        return held
    }

    /// The user undid `correction` of `typed` right after it was made.
    public mutating func recordUndo(of correction: String, typed: String) {
        undone.insert(Pair(typed: typed, correction: correction))
    }

    /// The user kept `typed` while `correction` waited to replace it.
    public mutating func recordRejection(of correction: String, typed: String, at date: Date) {
        let pair = Pair(typed: typed, correction: correction)
        undone.insert(pair)
        rejections[pair] = Rejection(count: (rejections[pair]?.count ?? 0) + 1, lastRejected: date)
        if rejections.count > Self.capacity,
           let oldest = rejections.min(by: { $0.value.lastRejected < $1.value.lastRejected })?.key {
            rejections[oldest] = nil
        }
    }

    /// The user chose `correction` for `typed`, so it may apply again.
    public mutating func recordAcceptance(of correction: String, typed: String) {
        let pair = Pair(typed: typed, correction: correction)
        undone.remove(pair)
        rejections[pair] = nil
    }

    /// Whether the user turned `correction` of `typed` down, for now or for good.
    public func remembers(_ correction: String, of typed: String) -> Bool {
        let pair = Pair(typed: typed, correction: correction)
        return undone.contains(pair) || rejections[pair] != nil
    }
}
