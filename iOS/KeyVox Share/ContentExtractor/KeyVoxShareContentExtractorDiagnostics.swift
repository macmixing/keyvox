import Foundation

enum KeyVoxShareContentExtractorDiagnostics {
    static func log(_ message: String) {
        NSLog("[KeyVoxShareContentExtractor] %@", message)
    }

    static func logExtractionSummary(for text: String, source: KeyVoxShareContentExtractor.ExtractionSource) {
        let words = text.split(whereSeparator: \.isWhitespace)
        let previewLimit = 220
        let prefixPreview = String(text.prefix(previewLimit)).replacingOccurrences(of: "\n", with: " ")
        let suffixPreview = String(text.suffix(previewLimit)).replacingOccurrences(of: "\n", with: " ")
        log(
            "Final \(source.rawValue) extraction chars=\(text.count) words=\(words.count) prefix=\"\(prefixPreview)\" suffix=\"\(suffixPreview)\""
        )
    }
}
