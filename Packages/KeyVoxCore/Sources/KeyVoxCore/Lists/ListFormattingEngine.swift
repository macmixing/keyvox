import Foundation

public struct ListFormattingEngine {
    private let detector = ListPatternDetector()
    private let renderer = ListRenderer()

    public init() {}

    public func formatIfNeeded(_ text: String, renderMode: ListRenderMode, languageCode: String? = nil) -> String {
        guard !text.isEmpty else { return text }
        guard let detectedList = detector.detectList(in: text, languageCode: languageCode) else { return text }
        return renderer.render(detectedList, mode: renderMode)
    }
}
