import Foundation

enum LeadingDateCapitalizationPolicy {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    static func shouldPreserveCapitalization(
        in text: String,
        startingAt capitalizationIndex: String.Index,
        locale: Locale = .current
    ) -> Bool {
        let leadingWordEnd = text[capitalizationIndex...]
            .firstIndex(where: { $0.isLetter == false }) ?? text.endIndex
        let leadingWord = String(text[capitalizationIndex..<leadingWordEnd])
        guard canonicalCalendarSymbols(for: locale).contains(leadingWord) else {
            return false
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let expectedLocation = NSRange(
            capitalizationIndex..<capitalizationIndex,
            in: text
        ).location
        if detector?.firstMatch(in: text, range: fullRange)?.range.location == expectedLocation {
            return true
        }

        return beginsWithLocalizedSpelledOutNumber(
            text[leadingWordEnd...],
            locale: locale
        )
    }

    private static func canonicalCalendarSymbols(for locale: Locale) -> Set<String> {
        let formatter = DateFormatter()
        formatter.locale = locale

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        let symbolGroups = [
            formatter.monthSymbols,
            formatter.shortMonthSymbols,
            formatter.standaloneMonthSymbols,
            formatter.shortStandaloneMonthSymbols,
            formatter.weekdaySymbols,
            formatter.shortWeekdaySymbols,
            formatter.standaloneWeekdaySymbols,
            formatter.shortStandaloneWeekdaySymbols,
        ]
        let trimmingCharacters = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)

        return Set(symbolGroups.compactMap { $0 }.flatMap { $0 }.map {
            $0.trimmingCharacters(in: trimmingCharacters)
        })
    }

    private static func beginsWithLocalizedSpelledOutNumber(
        _ suffix: Substring,
        locale: Locale
    ) -> Bool {
        guard let numberStart = suffix.firstIndex(where: \.isLetter) else {
            return false
        }
        let numberWord = String(suffix[numberStart...].prefix(while: \.isLetter))

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        return formatter.number(from: numberWord) != nil
    }
}
