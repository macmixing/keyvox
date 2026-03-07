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
