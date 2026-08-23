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
        let calendarSymbols = canonicalCalendarSymbols(for: locale)
        guard calendarSymbols.all.contains(leadingWord) else {
            return false
        }
        guard calendarSymbols.months.contains(leadingWord) == false else { return true }

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

    private static func canonicalCalendarSymbols(
        for locale: Locale
    ) -> (all: Set<String>, months: Set<String>) {
        let formatter = DateFormatter()
        formatter.locale = locale

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        let monthSymbolGroups = [
            formatter.monthSymbols,
            formatter.shortMonthSymbols,
            formatter.standaloneMonthSymbols,
            formatter.shortStandaloneMonthSymbols,
        ]
        let weekdaySymbolGroups = [
            formatter.weekdaySymbols,
            formatter.shortWeekdaySymbols,
            formatter.standaloneWeekdaySymbols,
            formatter.shortStandaloneWeekdaySymbols,
        ]
        let trimmingCharacters = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)

        let months = Set(monthSymbolGroups.compactMap { $0 }.flatMap { $0 }.map {
            $0.trimmingCharacters(in: trimmingCharacters)
        })
        let weekdays = Set(weekdaySymbolGroups.compactMap { $0 }.flatMap { $0 }.map {
            $0.trimmingCharacters(in: trimmingCharacters)
        })
        return (months.union(weekdays), months)
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
