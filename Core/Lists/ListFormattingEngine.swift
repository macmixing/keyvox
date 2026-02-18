import Foundation

struct ListFormattingEngine {
    private let detector = ListPatternDetector()
    private let renderer = ListRenderer()

    func formatIfNeeded(_ text: String, renderMode: ListRenderMode) -> String {
        guard !text.isEmpty else { return text }
        guard let detectedList = detector.detectList(in: text) else { return text }
        return renderer.render(detectedList, mode: renderMode)
    }
}
