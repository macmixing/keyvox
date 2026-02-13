import Foundation

public struct Segment: Sendable {
    public let startTime: Int
    public let endTime: Int
    public let text: String

    public init(startTime: Int, endTime: Int, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
