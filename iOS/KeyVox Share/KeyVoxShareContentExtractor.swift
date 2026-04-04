import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit
import Vision

enum KeyVoxShareContentExtractor {
    private enum OCRPolicy {
        static let maximumRecognitionWidth: CGFloat = 2_048
        static let tileHeight: CGFloat = 1_536
        static let tileOverlap: CGFloat = 96
    }

    static func extractText(from extensionContext: NSExtensionContext?) async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            log("No extension input items were available.")
            return nil
        }

        log("Received \(items.count) extension item(s).")

        let directText = await extractDirectText(from: items)
        if directText.isEmpty == false {
            log("Using directly shared text length=\(directText.count).")
            return directText
        }

        let recognizedText = await extractRecognizedText(from: items)
        if recognizedText.isEmpty == false {
            log("Using OCR text length=\(recognizedText.count).")
            return recognizedText
        }

        log("No text could be extracted from share payload.")
        return nil
    }

    private static func extractDirectText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []

        for item in items {
            if let attributedString = item.attributedContentText?.string,
               let normalized = normalizeText(attributedString) {
                log("Found attributedContentText length=\(normalized.count).")
                segments.append(normalized)
            }

            for provider in item.attachments ?? [] {
                if let text = await loadText(from: provider) {
                    segments.append(text)
                }
            }
        }

        return joinedText(from: segments)
    }

    private static func extractRecognizedText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await loadRecognizedText(from: provider) {
                    segments.append(text)
                }
            }
        }

        return joinedText(from: segments)
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        let supportedTypeIdentifiers = [
            UTType.plainText.identifier,
            UTType.text.identifier,
            UTType.utf8PlainText.identifier
        ]

        for typeIdentifier in supportedTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            do {
                log("Attempting direct text load for type=\(typeIdentifier).")
                let item = try await loadItem(from: provider, typeIdentifier: typeIdentifier)
                if let text = normalizeText(from: item) {
                    log("Loaded direct text length=\(text.count) for type=\(typeIdentifier).")
                    return text
                }
            } catch {
                log("Direct text load failed for type=\(typeIdentifier): \(error.localizedDescription)")
                continue
            }
        }

        return nil
    }

    private static func loadRecognizedText(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        do {
            log("Attempting generic image item load.")
            if let imageItem = try await loadItem(from: provider, typeIdentifier: UTType.image.identifier) {
                log("Loaded generic image item type=\(String(describing: type(of: imageItem))).")
                if let recognizedText = try recognizeText(fromImageCarrier: imageItem) {
                    return recognizedText
                }
            }

            if let image = try await loadObjectImage(from: provider) {
                log("Loaded UIImage-backed share image size=\(Int(image.size.width))x\(Int(image.size.height)).")
                return try recognizeText(in: image)
            }

            log("Attempting file-backed image OCR load.")
            if let fileURL = try await loadFileRepresentation(from: provider, typeIdentifier: UTType.image.identifier) {
                log("Loaded file-backed image at \(fileURL.path).")
                return try recognizeText(at: fileURL)
            }

            log("File-backed image load returned nil URL; falling back to data representation.")
            let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.image.identifier)
            log("Loaded in-memory image data bytes=\(data.count).")
            return try recognizeText(in: data)
        } catch {
            log("Image OCR load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func recognizeText(fromImageCarrier item: NSSecureCoding) throws -> String? {
        if let image = item as? UIImage {
            return try recognizeText(in: image)
        }

        if let url = item as? URL {
            let persistentURL = try makePersistentCopy(of: url)
            log("Recognizing text from generic item URL \(persistentURL.path).")
            return try recognizeText(at: persistentURL)
        }

        if let data = item as? Data {
            if let recognizedText = try recognizeText(in: data) {
                return recognizedText
            }

            if let plistPayloadText = try recognizeTextFromPropertyListData(data) {
                return plistPayloadText
            }
        }

        if let dictionary = item as? NSDictionary,
           let recognizedText = try recognizeText(fromPropertyListObject: dictionary) {
            return recognizedText
        }

        if let array = item as? NSArray {
            for element in array {
                if let recognizedText = try recognizeText(fromPropertyListObject: element) {
                    return recognizedText
                }
            }
        }

        return nil
    }

    private static func recognizeText(in image: UIImage) throws -> String? {
        guard let cgImage = preparedImage(from: image) else {
            log("Failed to prepare OCR image from UIImage.")
            return nil
        }

        log("Prepared OCR image from UIImage width=\(cgImage.width) height=\(cgImage.height).")
        let recognizedStrings = try recognizeTextLines(in: cgImage)
        let normalized = joinedText(from: recognizedStrings)
        return normalized.isEmpty ? nil : normalized
    }

    private static func recognizeText(at imageURL: URL) throws -> String? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = preparedImage(from: imageSource) else {
            log("Failed to decode image from file URL \(imageURL.path).")
            return nil
        }

        log("Prepared OCR image from file width=\(cgImage.width) height=\(cgImage.height).")
        let recognizedStrings = try recognizeTextLines(in: cgImage)
        let normalized = joinedText(from: recognizedStrings)
        return normalized.isEmpty ? nil : normalized
    }

    private static func recognizeText(in imageData: Data) throws -> String? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = preparedImage(from: imageSource) else {
            log("Failed to decode image from data bytes=\(imageData.count).")
            return nil
        }

        log("Prepared OCR image from data width=\(cgImage.width) height=\(cgImage.height).")
        let recognizedStrings = try recognizeTextLines(in: cgImage)
        let normalized = joinedText(from: recognizedStrings)
        return normalized.isEmpty ? nil : normalized
    }

    private static func recognizeTextLines(in image: CGImage) throws -> [String] {
        let tileRects = recognitionTileRects(for: image)
        log("Recognizing text across \(tileRects.count) tile(s).")
        var recognizedStrings: [String] = []

        for (index, tileRect) in tileRects.enumerated() {
            guard let tileImage = image.cropping(to: tileRect.integral) else { continue }
            log(
                "Running OCR on tile \(index + 1)/\(tileRects.count) width=\(tileImage.width) height=\(tileImage.height) originY=\(Int(tileRect.origin.y))."
            )

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: tileImage)
            try handler.perform([request])

            let tileStrings = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            log("OCR tile \(index + 1) produced \(tileStrings.count) candidate line(s).")
            recognizedStrings.append(contentsOf: tileStrings)
        }

        let deduplicatedStrings = deduplicatedRecognizedLines(recognizedStrings)
        if deduplicatedStrings.count != recognizedStrings.count {
            log("Deduplicated OCR lines from \(recognizedStrings.count) to \(deduplicatedStrings.count).")
        }
        return deduplicatedStrings
    }

    private static func preparedImage(from imageSource: CGImageSource) -> CGImage? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              properties[kCGImagePropertyPixelHeight] as? CGFloat != nil else {
            log("Image properties were unavailable; using original decoded image.")
            return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }

        guard let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            log("Failed to decode source image from image source.")
            return nil
        }

        if pixelWidth <= OCRPolicy.maximumRecognitionWidth {
            log("Using original image width=\(Int(pixelWidth)) height=\(sourceImage.height).")
            return sourceImage
        }

        log("Scaling image width from \(Int(pixelWidth)) to \(Int(OCRPolicy.maximumRecognitionWidth)).")
        return scaledImage(sourceImage, maximumWidth: OCRPolicy.maximumRecognitionWidth)
    }

    private static func preparedImage(from image: UIImage) -> CGImage? {
        let sourceImage: CGImage
        if let cgImage = image.cgImage {
            sourceImage = cgImage
        } else if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            guard let renderedImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                log("Failed to render CGImage from CIImage-backed UIImage.")
                return nil
            }
            sourceImage = renderedImage
        } else {
            return nil
        }

        if CGFloat(sourceImage.width) <= OCRPolicy.maximumRecognitionWidth {
            return sourceImage
        }

        log("Scaling UIImage width from \(sourceImage.width) to \(Int(OCRPolicy.maximumRecognitionWidth)).")
        return scaledImage(sourceImage, maximumWidth: OCRPolicy.maximumRecognitionWidth)
    }

    private static func recognitionTileRects(for image: CGImage) -> [CGRect] {
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard imageRect.height > OCRPolicy.tileHeight else {
            return [imageRect]
        }

        var rects: [CGRect] = []
        let stride = max(OCRPolicy.tileHeight - OCRPolicy.tileOverlap, 1)
        var originY: CGFloat = 0

        while originY < imageRect.height {
            let height = min(OCRPolicy.tileHeight, imageRect.height - originY)
            rects.append(CGRect(x: 0, y: originY, width: imageRect.width, height: height))

            if originY + height >= imageRect.height {
                break
            }

            originY += stride
        }

        return rects
    }

    private static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: item)
            }
        }
    }

    private static func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private static func loadFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let persistentURL = try makePersistentCopy(of: url)
                    continuation.resume(returning: persistentURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func loadObjectImage(from provider: NSItemProvider) async throws -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            log("Provider cannot load UIImage directly; continuing to file-backed OCR.")
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: UIImage.self) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: image as? UIImage)
            }
        }
    }

    private static func recognizeTextFromPropertyListData(_ data: Data) throws -> String? {
        guard data.starts(with: [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74]) else {
            return nil
        }

        log("Inspecting property-list-backed image payload bytes=\(data.count).")
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try recognizeText(fromPropertyListObject: propertyList)
    }

    private static func recognizeText(fromPropertyListObject object: Any) throws -> String? {
        if let image = object as? UIImage {
            return try recognizeText(in: image)
        }

        if let data = object as? Data {
            return try recognizeText(in: data)
        }

        if let url = object as? URL {
            let persistentURL = try makePersistentCopy(of: url)
            return try recognizeText(at: persistentURL)
        }

        if let dictionary = object as? [AnyHashable: Any] {
            for value in dictionary.values {
                if let recognizedText = try recognizeText(fromPropertyListObject: value) {
                    return recognizedText
                }
            }
            return nil
        }

        if let array = object as? [Any] {
            for value in array {
                if let recognizedText = try recognizeText(fromPropertyListObject: value) {
                    return recognizedText
                }
            }
        }

        return nil
    }

    private static func scaledImage(_ image: CGImage, maximumWidth: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > maximumWidth else { return image }

        let scale = maximumWidth / width
        let targetSize = CGSize(
            width: maximumWidth.rounded(.down),
            height: max((height * scale).rounded(.down), 1)
        )

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            log("Failed to create scaling context; using original image.")
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        let scaledImage = context.makeImage() ?? image
        log("Scaled image result width=\(scaledImage.width) height=\(scaledImage.height).")
        return scaledImage
    }

    private static func deduplicatedRecognizedLines(_ lines: [String]) -> [String] {
        var deduplicated: [String] = []
        var recentNormalizedLines: [String] = []

        for line in lines {
            guard let normalizedLine = normalizedComparisonText(for: line) else { continue }

            if recentNormalizedLines.contains(normalizedLine) {
                continue
            }

            deduplicated.append(line)
            recentNormalizedLines.append(normalizedLine)
            if recentNormalizedLines.count > 6 {
                recentNormalizedLines.removeFirst(recentNormalizedLines.count - 6)
            }
        }

        return deduplicated
    }

    private static func normalizedComparisonText(for text: String) -> String? {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted.union(.whitespacesAndNewlines))

        return folded.isEmpty ? nil : folded
    }

    private static func makePersistentCopy(of fileURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let destinationURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileURL.lastPathComponent, isDirectory: false)

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: fileURL, to: destinationURL)
        log("Copied shared file into persistent temporary URL \(destinationURL.path).")
        return destinationURL
    }

    private static func log(_ message: String) {
        NSLog("[KeyVoxShareContentExtractor] %@", message)
    }

    private static func normalizeText(from item: NSSecureCoding?) -> String? {
        if let string = item as? String {
            return normalizeText(string)
        }

        if let attributedString = item as? NSAttributedString {
            return normalizeText(attributedString.string)
        }

        if let url = item as? URL,
           let data = try? Data(contentsOf: url) {
            if let string = String(data: data, encoding: .utf8) {
                return normalizeText(string)
            }
            if let string = String(data: data, encoding: .unicode) {
                return normalizeText(string)
            }
        }

        if let data = item as? Data {
            if let string = String(data: data, encoding: .utf8) {
                return normalizeText(string)
            }
            if let string = String(data: data, encoding: .unicode) {
                return normalizeText(string)
            }
        }

        return nil
    }

    private static func normalizeText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func joinedText(from segments: [String]) -> String {
        segments
            .compactMap(normalizeText(_:))
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
