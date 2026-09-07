import Foundation
import KeyVoxTextComposition

public enum CompositionVerification {
    private struct Failure: Error { let check: String }

    public static func verify() throws {
        let label = UUID().uuidString.lowercased()
        var url = URLComponents()
        url.scheme = "https"
        url.host = label + ".example"
        url.path = "/" + label
        guard let address = url.string else { throw Failure(check: "URL construction") }
        for candidate in [address, url.host!, label + "@" + url.host!] {
            guard PortableLinkPrefixDetector.startsWithLink(candidate) else {
                throw Failure(check: "structured link")
            }
            let punctuation = (0...0x7f).compactMap(UnicodeScalar.init)
                .filter(CharacterSet.punctuationCharacters.contains)
            for scalar in punctuation {
                guard PortableLinkPrefixDetector.startsWithLink(candidate + String(scalar)) else {
                    throw Failure(check: "link before punctuation")
                }
            }
        }
        for candidate in ["", label, "192.168", "-" + url.host!] {
            guard !PortableLinkPrefixDetector.startsWithLink(candidate) else {
                throw Failure(check: "non-link")
            }
        }

        let transcript = label + "."
        let result = TerminalPunctuationCompositionPolicy.resolve(
            text: transcript,
            followingCharacter: " ",
            followingNonWhitespaceCharacter: address.first,
            followingText: " " + address
        )
        guard result.text == transcript, !result.shouldReplaceFollowingPunctuation else {
            throw Failure(check: "transcript boundary before URL")
        }

        // Locale identifiers choose system data; no calendar vocabulary is embedded.
        for identifier in ["en_US", "fr_FR", "de_DE", "es_ES", "tr_TR", "ja_JP"] {
            let locale = Locale(identifier: identifier)
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = Calendar(identifier: .gregorian)
            for weekday in formatter.weekdaySymbols where weekday.allSatisfy(\.isLetter) {
                guard CalendarDatePrefixDetector.startsWithFullWeekday(
                    weekday, at: weekday.startIndex, locale: locale
                ) else { throw Failure(check: "localized weekday") }
            }
        }
    }
}
