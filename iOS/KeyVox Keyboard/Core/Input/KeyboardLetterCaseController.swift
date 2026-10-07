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
/// locks caps, and the field's own auto-capitalization setting decides when the
/// keyboard shifts by itself.
final class KeyboardLetterCaseController {
    private enum Timing {
        static let capsLockTapInterval: TimeInterval = 0.35
    }

    private(set) var letterCase: KeyboardLetterCase = .lowercase
    private var lastShiftTapTimestamp: TimeInterval?

    func handleShift(at timestamp: TimeInterval) {
        if letterCase != .capsLocked,
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
        case .shifted, .capsLocked:
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

    /// Re-derives the automatic shift from the text before the cursor.
    func synchronize(
        textBeforeCursor: String?,
        autocapitalization: UITextAutocapitalizationType
    ) {
        guard letterCase != .capsLocked else { return }
        letterCase = Self.shouldAutoCapitalize(
            textBeforeCursor: textBeforeCursor ?? "",
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
        case .allCharacters:
            return true
        case .words:
            return textBeforeCursor.last.map { $0.isWhitespace || $0.isNewline } ?? true
        case .sentences:
            guard let last = textBeforeCursor.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            return TypingTextContext.startsSentence(
                after: textBeforeCursor.trimmingCharacters(in: .whitespaces)
            )
        @unknown default:
            return false
        }
    }
}
