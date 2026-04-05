import Foundation

enum KeyVoxShareContentExtractorDiagnostics {
    static func log(_ message: String) {
        NSLog("[KeyVoxShareContentExtractor] %@", message)
    }

    static func logExtractionSummary(for text: String, source: KeyVoxShareContentExtractor.ExtractionSource) {
        let words = text.split(whereSeparator: \.isWhitespace)
        log(
            "Final \(source.rawValue) extraction chars=\(text.count) words=\(words.count)"
        )
    }
}
