import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum KeyVoxSharePDFExtractor {
    static func extractText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []
        var seenComparisons: Set<String> = []

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await loadPDFText(from: provider) {
                    KeyVoxShareTextSupport.appendIfDistinct(
                        text,
                        to: &segments,
                        seenComparisons: &seenComparisons
                    )
                }
            }
        }

        return KeyVoxShareTextSupport.joinedText(from: segments)
    }

    private static func loadPDFText(from provider: NSItemProvider) async -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            do {
                KeyVoxShareContentExtractorDiagnostics.log("Attempting PDF item load.")
                if let item = try await KeyVoxShareItemProviderLoader.loadItem(
                    from: provider,
                    typeIdentifier: UTType.pdf.identifier
                ),
                   let text = extractText(fromPDFCarrier: item) {
                    return text
                }
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log("PDF item load failed: \(error.localizedDescription)")
            }

            do {
                KeyVoxShareContentExtractorDiagnostics.log("Attempting file-backed PDF load.")
                if let fileURL = try await KeyVoxShareItemProviderLoader.loadFileRepresentation(
                    from: provider,
                    typeIdentifier: UTType.pdf.identifier
                ) {
                    defer {
                        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
                    }
                    return extractText(fromPDFAt: fileURL)
                }
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log("File-backed PDF load failed: \(error.localizedDescription)")
            }

            do {
                let data = try await KeyVoxShareItemProviderLoader.loadDataRepresentation(
                    from: provider,
                    typeIdentifier: UTType.pdf.identifier
                )
                KeyVoxShareContentExtractorDiagnostics.log("Loaded in-memory PDF data bytes=\(data.count).")
                return extractText(fromPDFData: data)
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log("Data-backed PDF load failed: \(error.localizedDescription)")
            }
        }

        return await loadPDFTextFromFileURLProvider(provider)
    }

    private static func loadPDFTextFromFileURLProvider(_ provider: NSItemProvider) async -> String? {
        for typeIdentifier in [UTType.fileURL.identifier, UTType.url.identifier]
            where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            do {
                let item = try await KeyVoxShareItemProviderLoader.loadItem(
                    from: provider,
                    typeIdentifier: typeIdentifier
                )
                guard let url = item as? URL,
                      isPDFURL(url) else {
                    continue
                }

                if url.isFileURL == false {
                    if let text = await loadRemotePDFText(from: url) {
                        return text
                    }
                    continue
                }

                let persistentURL = try KeyVoxShareItemProviderLoader.makePersistentCopy(of: url)
                defer {
                    try? FileManager.default.removeItem(at: persistentURL.deletingLastPathComponent())
                }
                KeyVoxShareContentExtractorDiagnostics.log("Loaded file URL PDF at \(persistentURL.path).")
                return extractText(fromPDFAt: persistentURL)
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "File URL PDF load failed for type=\(typeIdentifier): \(error.localizedDescription)"
                )
            }
        }

        return nil
    }

    private static func isPDFURL(_ url: URL) -> Bool {
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .pdf) {
            return true
        }

        return url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
    }

    private static func loadRemotePDFText(from url: URL) async -> String? {
        guard url.scheme == "http" || url.scheme == "https" else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               200..<300 ~= httpResponse.statusCode {
                KeyVoxShareContentExtractorDiagnostics.log("Loaded remote PDF data bytes=\(data.count).")
                return extractText(fromPDFData: data)
            }
        } catch {
            KeyVoxShareContentExtractorDiagnostics.log("Remote PDF load failed: \(error.localizedDescription)")
        }

        return nil
    }

    private static func extractText(fromPDFCarrier item: NSSecureCoding) -> String? {
        if let url = item as? URL {
            do {
                let persistentURL = try KeyVoxShareItemProviderLoader.makePersistentCopy(of: url)
                defer {
                    try? FileManager.default.removeItem(at: persistentURL.deletingLastPathComponent())
                }
                return extractText(fromPDFAt: persistentURL)
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log("PDF URL copy failed: \(error.localizedDescription)")
                return nil
            }
        }

        if let data = item as? Data {
            return extractText(fromPDFData: data)
        }

        return nil
    }

    private static func extractText(fromPDFAt fileURL: URL) -> String? {
        guard let document = PDFDocument(url: fileURL) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to open PDF at \(fileURL.path).")
            return nil
        }

        return extractText(from: document)
    }

    private static func extractText(fromPDFData data: Data) -> String? {
        guard let document = PDFDocument(data: data) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to open PDF from data bytes=\(data.count).")
            return nil
        }

        return extractText(from: document)
    }

    private static func extractText(from document: PDFDocument) -> String? {
        KeyVoxShareContentExtractorDiagnostics.log("Inspecting PDF pageCount=\(document.pageCount).")
        var pageSegments: [String] = []
        var seenComparisons: Set<String> = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            if let selectableText = KeyVoxShareTextSupport.reflowSoftLineBreaks(page.string ?? "") {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Loaded selectable PDF text page=\(pageIndex + 1) length=\(selectableText.count)."
                )
                KeyVoxShareTextSupport.appendIfDistinct(
                    selectableText,
                    to: &pageSegments,
                    seenComparisons: &seenComparisons
                )
                continue
            }

            if let ocrText = recognizeTextOnRenderedPDFPage(page, pageIndex: pageIndex),
               let reflowedOCRText = KeyVoxShareTextSupport.reflowSoftLineBreaks(ocrText) {
                KeyVoxShareTextSupport.appendIfDistinct(
                    reflowedOCRText,
                    to: &pageSegments,
                    seenComparisons: &seenComparisons
                )
            }
        }

        let text = KeyVoxShareTextSupport.joinedText(from: pageSegments)
        return text.isEmpty ? nil : text
    }

    private static func recognizeTextOnRenderedPDFPage(_ page: PDFPage, pageIndex: Int) -> String? {
        do {
            guard let layout = tileLayout(for: page) else {
                KeyVoxShareContentExtractorDiagnostics.log("Failed to prepare PDF page=\(pageIndex + 1) for OCR.")
                return nil
            }

            KeyVoxShareContentExtractorDiagnostics.log(
                "Running OCR fallback on PDF page=\(pageIndex + 1) renderSize=\(Int(layout.targetSize.width))x\(Int(layout.targetSize.height)) tileCount=\(layout.tileRects.count)."
            )

            return try KeyVoxShareOCRPipeline.recognizeText(
                tileCount: layout.tileRects.count
            ) { tileIndex in
                let tileRect = layout.tileRects[tileIndex]
                guard let tileImage = renderedTile(from: page, layout: layout, tileRect: tileRect) else {
                    KeyVoxShareContentExtractorDiagnostics.log(
                        "Failed to render PDF page=\(pageIndex + 1) tile=\(tileIndex + 1)."
                    )
                    return nil
                }

                return KeyVoxShareOCRTile(image: tileImage, rect: tileRect)
            }
        } catch {
            KeyVoxShareContentExtractorDiagnostics.log(
                "PDF OCR fallback failed page=\(pageIndex + 1): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private struct PDFTileLayout {
        let bounds: CGRect
        let scale: CGFloat
        let targetSize: CGSize
        let tileRects: [CGRect]
    }

    private static func tileLayout(for page: PDFPage) -> PDFTileLayout? {
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        let scale = KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth / bounds.width
        let targetSize = CGSize(
            width: max((bounds.width * scale).rounded(.up), 1),
            height: max((bounds.height * scale).rounded(.up), 1)
        )
        let tileRects = KeyVoxShareOCRRenderingPolicy.tileRects(for: targetSize)

        return PDFTileLayout(
            bounds: bounds,
            scale: scale,
            targetSize: targetSize,
            tileRects: tileRects
        )
    }

    private static func renderedTile(from page: PDFPage, layout: PDFTileLayout, tileRect: CGRect) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let tileSize = CGSize(
            width: max(tileRect.width.rounded(.up), 1),
            height: max(tileRect.height.rounded(.up), 1)
        )
        let renderer = UIGraphicsImageRenderer(size: tileSize, format: format)
        let image = renderer.image { rendererContext in
            UIColor.white.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: tileSize))

            let context = rendererContext.cgContext
            context.saveGState()
            context.translateBy(x: -tileRect.minX, y: -tileRect.minY)
            context.scaleBy(x: layout.scale, y: layout.scale)
            context.translateBy(x: 0, y: layout.bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -layout.bounds.minX, y: -layout.bounds.minY)
            page.draw(with: .cropBox, to: context)
            context.restoreGState()
        }

        return image.cgImage
    }
}
