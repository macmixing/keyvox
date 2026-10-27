import KeyVoxPredictiveKeyboard
import UIKit

enum KeyboardLetterCase: Equatable {
    case lowercase
    case shifted
    case capsLocked

    var usesUppercaseLetters: Bool {
        self != .lowercase
    }
}

/// Owns the letter page's shift state: a tap shifts the next letter, a quick second tap
/// locks caps when caps lock is allowed, and the field's auto-capitalization decides when
/// the keyboard shifts by itself.
final class KeyboardLetterCaseController {
    private enum Timing {
        static let capsLockTapInterval: TimeInterval = 0.35
    }

    private static let attachmentCharacter = Character(Unicode.Scalar(UInt16(NSTextAttachment.character))!)

    private(set) var letterCase: KeyboardLetterCase = .lowercase
    private var lastShiftTapTimestamp: TimeInterval?

    func handleShift(at timestamp: TimeInterval, allowsCapsLock: Bool = true) {
        if allowsCapsLock,
           letterCase != .capsLocked,
           let lastShiftTapTimestamp,
           timestamp - lastShiftTapTimestamp <= Timing.capsLockTapInterval {
            letterCase = .capsLocked
            self.lastShiftTapTimestamp = nil
            return
        }

        switch letterCase {
        case .lowercase:
            letterCase = .shifted
            lastShiftTapTimestamp = timestamp
        case .shifted:
            // A quick second tap locks caps whether the user or the field shifted the letters.
            letterCase = .lowercase
            lastShiftTapTimestamp = timestamp
        case .capsLocked:
            letterCase = .lowercase
            lastShiftTapTimestamp = nil
        }
    }

    /// Call after a letter was typed: a one-letter shift ends, caps lock stays.
    func consumeTypedLetter() {
        guard letterCase == .shifted else { return }
        letterCase = .lowercase
        lastShiftTapTimestamp = nil
    }

    /// Re-derives the automatic shift from the text before the cursor. Attachments are objects
    /// in the field rather than typed text, so their placeholders are skipped.
    func synchronize(
        textBeforeCursor: String?,
        autocapitalization: UITextAutocapitalizationType
    ) {
        guard letterCase != .capsLocked else { return }
        letterCase = Self.shouldAutoCapitalize(
            textBeforeCursor: (textBeforeCursor ?? "").filter { $0 != Self.attachmentCharacter },
            autocapitalization: autocapitalization
        ) ? .shifted : .lowercase
        lastShiftTapTimestamp = nil
    }

    func reset() {
        letterCase = .lowercase
        lastShiftTapTimestamp = nil
    }

    static func shouldAutoCapitalize(
        textBeforeCursor: String,
        autocapitalization: UITextAutocapitalizationType
    ) -> Bool {
        switch autocapitalization {
        case .none:
            return false
        case .words:
            return textBeforeCursor.last.map { $0.isWhitespace || $0.isNewline } ?? true
        // A field asking for every letter capitalized still shifts only at sentence starts,
        // as other keyboards do; caps lock stays the user's to turn on.
        case .sentences, .allCharacters:
            return TypingTextContext.startsSentence(after: textBeforeCursor)
        @unknown default:
            return false
        }
    }
}
