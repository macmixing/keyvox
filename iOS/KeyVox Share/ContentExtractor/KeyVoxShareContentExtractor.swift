import Foundation

enum KeyVoxShareContentExtractor {
    enum ExtractionSource: String {
        case direct
        case web
        case ocr
    }

    static func extractText(from extensionContext: NSExtensionContext?) async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            KeyVoxShareContentExtractorDiagnostics.log("No extension input items were available.")
            return nil
        }

        KeyVoxShareContentExtractorDiagnostics.log("Received \(items.count) extension item(s).")

        let directText = await KeyVoxShareDirectTextExtractor.extractText(from: items)
        if directText.isEmpty == false {
            KeyVoxShareContentExtractorDiagnostics.log("Using directly shared text length=\(directText.count).")
            KeyVoxShareContentExtractorDiagnostics.logExtractionSummary(for: directText, source: .direct)
            return directText
        }

        let webText = await KeyVoxShareWebExtractor.extractText(from: items)
        if webText.isEmpty == false {
            KeyVoxShareContentExtractorDiagnostics.log("Using web parsed text length=\(webText.count).")
            KeyVoxShareContentExtractorDiagnostics.logExtractionSummary(for: webText, source: .web)
            return webText
        }

        let recognizedText = await KeyVoxShareImageOCRExtractor.extractText(from: items)
        if recognizedText.isEmpty == false {
            KeyVoxShareContentExtractorDiagnostics.log("Using OCR text length=\(recognizedText.count).")
            KeyVoxShareContentExtractorDiagnostics.logExtractionSummary(for: recognizedText, source: .ocr)
            return recognizedText
        }

        KeyVoxShareContentExtractorDiagnostics.log("No text could be extracted from share payload.")
        return nil
    }
}
