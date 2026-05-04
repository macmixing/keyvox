import Foundation

public struct ListPatternMarker {
    public let number: Int
    public let markerTokenStart: Int
    public let contentStart: Int

    public init(number: Int, markerTokenStart: Int, contentStart: Int) {
        self.number = number
        self.markerTokenStart = markerTokenStart
        self.contentStart = contentStart
    }
}

enum ListPatternMarkerBounds {
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
