import UIKit

/// Records, for every assigned character from `SMART_DELETE_FIRST` up to `SMART_DELETE_END` (hex,
/// the Basic Multilingual Plane unless set), whether a text view's smart delete
/// removes a space next to a deleted word when that character sits on the word's other side, and
/// writes the result to `Documents/smart-delete-characters-<first>.json`.
///
/// - before: the character right before the word, with a space right after it, as in "one(two)
///   three" with "two" selected: whether the space after the word is removed.
/// - after: the character right after the word, with a space right before it, as in "one (two)x"
///   with "two" selected: whether the space before the word is removed.
/// - removable: the character as the only whitespace on one side, with a character the other side
///   that removes a space: whether that character is removed.
///
/// It also records the cursor after deleting a word between two spaces.
enum SmartDeleteCharacterProbe {
    private struct Record: Encodable {
        let scalar: UInt32
        let category: String
        let removesSpaceAfterWordWhenBefore: Bool
        let removesSpaceBeforeWordWhenAfter: Bool
        let isRemovedAfterWord: Bool
        let isRemovedBeforeWord: Bool
    }

    private struct Output: Encodable {
        let cursorAfterDeletingWordBetweenSpaces: Int
        let records: [Record]
    }

    private static let chunk: UInt32 = 256
    private static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private static let first = ProcessInfo.processInfo.environment["SMART_DELETE_FIRST"].flatMap { UInt32($0, radix: 16) } ?? 0x01
    private static let end = ProcessInfo.processInfo.environment["SMART_DELETE_END"].flatMap { UInt32($0, radix: 16) } ?? 0x10000
    /// `SMART_DELETE_MARKS=1` measures only the combining marks, which join the character before them.
    private static let measuresMarks = ProcessInfo.processInfo.environment["SMART_DELETE_MARKS"] == "1"

    /// Works through the characters a chunk per main-loop turn, so the screen keeps drawing, and
    /// writes how far it got to `Documents/smart-delete-progress.txt`.
    static func run(in textView: UITextView) {
        textView.smartInsertDeleteType = .yes
        // Checking spelling after every change is what makes the run slow.
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.becomeFirstResponder()
        let cursor = delete(in: textView, before: "one ", word: "two", after: " three").cursor
        measure(from: first, in: textView, records: []) { records in
            try? JSONEncoder().encode(Output(cursorAfterDeletingWordBetweenSpaces: cursor, records: records))
                .write(to: documents.appendingPathComponent("smart-delete-characters-\(measuresMarks ? "marks-" : "")\(String(first, radix: 16)).json"), options: .atomic)
        }
    }

    private static func measure(from start: UInt32, in textView: UITextView, records: [Record], then finish: @escaping ([Record]) -> Void) {
        var records = records
        let stop = min(start + chunk, end)
        for value in start..<stop {
            guard let scalar = Unicode.Scalar(value), measuresMarks ? isMark(scalar) : isStandalone(scalar) else { continue }
            let c = String(Character(scalar))
            records.append(Record(
                scalar: value,
                category: "\(scalar.properties.generalCategory)",
                removesSpaceAfterWordWhenBefore: delete(in: textView, before: "one" + c, word: "two", after: " three").text
                    == "one" + c + "three",
                removesSpaceBeforeWordWhenAfter: delete(in: textView, before: "one ", word: "two", after: c + "three").text
                    == "one" + c + "three",
                isRemovedAfterWord: delete(in: textView, before: "one (", word: "two", after: c + "three").text
                    == "one (three",
                isRemovedBeforeWord: delete(in: textView, before: "one" + c, word: "two", after: ". three").text
                    == "one. three"
            ))
        }
        try? "\(String(stop, radix: 16)) of \(String(end, radix: 16))".write(to: documents.appendingPathComponent("smart-delete-progress.txt"), atomically: true, encoding: .utf8)
        guard stop < end else {
            finish(records)
            return
        }
        DispatchQueue.main.async {
            measure(from: stop, in: textView, records: records, then: finish)
        }
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        [.nonspacingMark, .spacingMark, .enclosingMark].contains(scalar.properties.generalCategory)
    }

    /// Characters that stay their own character next to a letter or a space.
    private static func isStandalone(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .surrogate, .unassigned, .privateUse:
            return false
        default:
            return String(Character(scalar)).count == 1 && ("a" + String(Character(scalar)) + "a").count == 3
        }
    }

    private static func delete(in textView: UITextView, before: String, word: String, after: String) -> (text: String, cursor: Int) {
        textView.text = before + word + after
        textView.selectedRange = NSRange(location: (before as NSString).length, length: (word as NSString).length)
        textView.deleteBackward()
        return (textView.text, textView.selectedRange.location)
    }
}
