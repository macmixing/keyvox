import Foundation

struct ListFormattingEngine {
    private let detector = ListPatternDetector()
    private let renderer = ListRenderer()

    func formatIfNeeded(_ text: String, renderMode: ListRenderMode, languageCode: String? = nil) -> String {
        guard !text.isEmpty else { return text }
        guard let detectedList = detector.detectList(in: text, languageCode: languageCode) else { return text }
        return renderer.render(detectedList, mode: renderMode)
    }
}
