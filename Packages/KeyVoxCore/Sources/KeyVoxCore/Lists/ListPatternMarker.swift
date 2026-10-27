import Foundation

public struct ListPatternMarker {
    public let number: Int
    public let markerTokenStart: Int
    public let contentStart: Int
    /// Where the spoken marker begins, including a label word that belongs to it.
    public let labelStart: Int

    public init(number: Int, markerTokenStart: Int, contentStart: Int, labelStart: Int? = nil) {
        self.number = number
        self.markerTokenStart = markerTokenStart
        self.contentStart = contentStart
        self.labelStart = labelStart ?? markerTokenStart
    }
}

enum ListPatternMarkerBounds {
    /// The word directly before `index`, separated from it by whitespace only.
    static func precedingWordRange(before index: Int, in nsText: NSString) -> NSRange? {
        var wordEnd = index
        while wordEnd > 0 {
            let character = nsText.substring(with: NSRange(location: wordEnd - 1, length: 1))
            guard character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else { break }
            wordEnd -= 1
        }
        guard wordEnd < index else { return nil }

        var wordStart = wordEnd
        while wordStart > 0 {
            let character = nsText.substring(with: NSRange(location: wordStart - 1, length: 1))
            guard character.rangeOfCharacter(from: .letters) != nil else { break }
            wordStart -= 1
        }
        guard wordStart < wordEnd else { return nil }
        return NSRange(location: wordStart, length: wordEnd - wordStart)
    }

    static func markerTokenEnd(for marker: ListPatternMarker, in nsText: NSString) -> Int {
        var index = marker.markerTokenStart
        while index < nsText.length {
            let character = nsText.substring(with: NSRange(location: index, length: 1))
            guard character.rangeOfCharacter(from: .alphanumerics) != nil || character == "-" else { break }
            index += 1
        }
        return index
    }
}
