import Foundation

/// How much a held delete key deletes at once.
enum KeyboardDeleteGranularity: Equatable {
    case character
    /// Whole words, each with the spaces or line breaks after it.
    case words(Int)
}

/// When a held delete key repeats and how much each repeat deletes, as measured on the system
/// keyboard: after the press deletes one character, a pause of half a second, then a character
/// every tenth of a second, and from the twenty-first repeat on, two words every 0.35 seconds.
enum KeyboardDeleteRepeatSchedule {
    static let initialDelay: TimeInterval = 0.5
    static let characterInterval: TimeInterval = 0.1
    static let characterRepeats = 20
    static let wordInterval: TimeInterval = 0.35
    static let wordsPerRepeat = 2

    /// The wait before the repeat that follows `repeatCount` earlier repeats.
    static func delay(beforeRepeat repeatCount: Int) -> TimeInterval {
        if repeatCount == 0 { return initialDelay }
        return repeatCount <= characterRepeats ? characterInterval : wordInterval
    }

    /// What the repeat that follows `repeatCount` earlier repeats deletes.
    static func granularity(ofRepeat repeatCount: Int) -> KeyboardDeleteGranularity {
        repeatCount < characterRepeats ? .character : .words(wordsPerRepeat)
    }
}
