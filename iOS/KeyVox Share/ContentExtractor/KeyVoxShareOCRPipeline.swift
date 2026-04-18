import CoreGraphics
import Foundation
import ImageIO
import UIKit
import Vision

enum KeyVoxShareOCRPipeline {
    private enum OCRPolicy {
        static let paragraphGapMultiplier: CGFloat = 1.45
        static let columnAlignmentTolerance: CGFloat = 42
        static let wrapContinuationTolerance: CGFloat = 30
        static let duplicateIntersectionThreshold: CGFloat = 0.55
    }

    private struct OCRLine {
        let text: String
        let normalizedText: String
        let rect: CGRect
        let confidence: Float

        var midY: CGFloat { rect.midY }
        var maxY: CGFloat { rect.maxY }
        var minX: CGFloat { rect.minX }
        var maxX: CGFloat { rect.maxX }
        var height: CGFloat { rect.height }
    }

    static func recognizeText(in image: UIImage) throws -> String? {
        guard let cgImage = preparedImage(from: image) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to prepare OCR image from UIImage.")
            return nil
        }

        KeyVoxShareContentExtractorDiagnostics.log(
            "Prepared OCR image from UIImage width=\(cgImage.width) height=\(cgImage.height)."
        )
        let recognizedParagraphs = try recognizeTextParagraphs(in: cgImage)
        let normalized = KeyVoxShareTextSupport.joinedText(from: recognizedParagraphs)
        return normalized.isEmpty ? nil : normalized
    }

    static func recognizeText(at imageURL: URL) throws -> String? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = preparedImage(from: imageSource) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to decode image from file URL \(imageURL.path).")
            return nil
        }

        KeyVoxShareContentExtractorDiagnostics.log(
            "Prepared OCR image from file width=\(cgImage.width) height=\(cgImage.height)."
        )
        let recognizedParagraphs = try recognizeTextParagraphs(in: cgImage)
        let normalized = KeyVoxShareTextSupport.joinedText(from: recognizedParagraphs)
        return normalized.isEmpty ? nil : normalized
    }

    static func recognizeText(in imageData: Data) throws -> String? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = preparedImage(from: imageSource) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to decode image from data bytes=\(imageData.count).")
            return nil
        }

        KeyVoxShareContentExtractorDiagnostics.log(
            "Prepared OCR image from data width=\(cgImage.width) height=\(cgImage.height)."
        )
        let recognizedParagraphs = try recognizeTextParagraphs(in: cgImage)
        let normalized = KeyVoxShareTextSupport.joinedText(from: recognizedParagraphs)
        return normalized.isEmpty ? nil : normalized
    }

    static func recognizeText(
        tileCount: Int,
        tileProvider: (Int) -> KeyVoxShareOCRTile?
    ) throws -> String? {
        let recognizedParagraphs = try recognizeTextParagraphs(
            tileCount: tileCount,
            tileProvider: tileProvider
        )
        let normalized = KeyVoxShareTextSupport.joinedText(from: recognizedParagraphs)
        return normalized.isEmpty ? nil : normalized
    }

    private static func recognizeTextParagraphs(in image: CGImage) throws -> [String] {
        let imageSize = CGSize(width: image.width, height: image.height)
        let tileRects = KeyVoxShareOCRRenderingPolicy.tileRects(for: imageSize)

        return try recognizeTextParagraphs(tileCount: tileRects.count) { index in
            let tileRect = tileRects[index]
            guard let tileImage = image.cropping(to: tileRect.integral) else {
                return nil
            }

            return KeyVoxShareOCRTile(image: tileImage, rect: tileRect)
        }
    }

    private static func recognizeTextParagraphs(
        tileCount: Int,
        tileProvider: (Int) -> KeyVoxShareOCRTile?
    ) throws -> [String] {
        KeyVoxShareContentExtractorDiagnostics.log("Recognizing text across \(tileCount) tile(s).")
        var recognizedLines: [OCRLine] = []

        for index in 0..<tileCount {
            guard let tile = tileProvider(index) else { continue }
            KeyVoxShareContentExtractorDiagnostics.log(
                "Running OCR on tile \(index + 1)/\(tileCount) width=\(tile.image.width) height=\(tile.image.height) originY=\(Int(tile.rect.origin.y))."
            )

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: tile.image)
            try handler.perform([request])

            let tileLines = ocrLines(from: request.results ?? [], tileRect: tile.rect, tileImage: tile.image)
            KeyVoxShareContentExtractorDiagnostics.log(
                "OCR tile \(index + 1) produced \(tileLines.count) positioned line(s)."
            )
            recognizedLines.append(contentsOf: tileLines)
        }

        let deduplicatedLines = deduplicatedRecognizedLines(recognizedLines)
        if deduplicatedLines.count != recognizedLines.count {
            KeyVoxShareContentExtractorDiagnostics.log(
                "Deduplicated OCR lines from \(recognizedLines.count) to \(deduplicatedLines.count)."
            )
        }

        let paragraphs = articleParagraphs(from: deduplicatedLines)
        KeyVoxShareContentExtractorDiagnostics.log("Assembled \(paragraphs.count) OCR paragraph(s).")
        return paragraphs
    }

    private static func ocrLines(
        from observations: [VNRecognizedTextObservation],
        tileRect: CGRect,
        tileImage: CGImage
    ) -> [OCRLine] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  let normalizedText = KeyVoxShareTextSupport.normalizedComparisonText(for: candidate.string) else {
                return nil
            }

            let boundingBox = observation.boundingBox
            let width = boundingBox.width * CGFloat(tileImage.width)
            let height = boundingBox.height * CGFloat(tileImage.height)
            let x = tileRect.minX + (boundingBox.minX * CGFloat(tileImage.width))
            let y = tileRect.minY + ((1 - boundingBox.maxY) * CGFloat(tileImage.height))
            let rect = CGRect(x: x, y: y, width: width, height: height).integral

            return OCRLine(
                text: candidate.string,
                normalizedText: normalizedText,
                rect: rect,
                confidence: candidate.confidence
            )
        }
    }

    private static func preparedImage(from imageSource: CGImageSource) -> CGImage? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              properties[kCGImagePropertyPixelHeight] as? CGFloat != nil else {
            KeyVoxShareContentExtractorDiagnostics.log("Image properties were unavailable; using original decoded image.")
            return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }

        guard let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to decode source image from image source.")
            return nil
        }

        if pixelWidth <= KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth {
            KeyVoxShareContentExtractorDiagnostics.log(
                "Using original image width=\(Int(pixelWidth)) height=\(sourceImage.height)."
            )
            return sourceImage
        }

        KeyVoxShareContentExtractorDiagnostics.log(
            "Scaling image width from \(Int(pixelWidth)) to \(Int(KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth))."
        )
        return scaledImage(sourceImage, maximumWidth: KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth)
    }

    private static func preparedImage(from image: UIImage) -> CGImage? {
        let sourceImage: CGImage
        if let cgImage = image.cgImage {
            sourceImage = cgImage
        } else if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            guard let renderedImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                KeyVoxShareContentExtractorDiagnostics.log("Failed to render CGImage from CIImage-backed UIImage.")
                return nil
            }
            sourceImage = renderedImage
        } else {
            return nil
        }

        if CGFloat(sourceImage.width) <= KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth {
            return sourceImage
        }

        KeyVoxShareContentExtractorDiagnostics.log(
            "Scaling UIImage width from \(sourceImage.width) to \(Int(KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth))."
        )
        return scaledImage(sourceImage, maximumWidth: KeyVoxShareOCRRenderingPolicy.maximumRecognitionWidth)
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
            KeyVoxShareContentExtractorDiagnostics.log("Failed to create scaling context; using original image.")
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        let scaledImage = context.makeImage() ?? image
        KeyVoxShareContentExtractorDiagnostics.log(
            "Scaled image result width=\(scaledImage.width) height=\(scaledImage.height)."
        )
        return scaledImage
    }

    private static func deduplicatedRecognizedLines(_ lines: [OCRLine]) -> [OCRLine] {
        let sortedLines = lines.sorted {
            if abs($0.midY - $1.midY) > 8 {
                return $0.midY < $1.midY
            }
            if abs($0.minX - $1.minX) > 8 {
                return $0.minX < $1.minX
            }
            return $0.confidence > $1.confidence
        }

        var deduplicated: [OCRLine] = []
        for line in sortedLines {
            let isDuplicate = deduplicated.contains { existingLine in
                areLikelyDuplicateLines(existingLine, line)
            }

            if isDuplicate == false {
                deduplicated.append(line)
            }
        }

        return deduplicated
    }

    private static func areLikelyDuplicateLines(_ lhs: OCRLine, _ rhs: OCRLine) -> Bool {
        let sameText = lhs.normalizedText == rhs.normalizedText
            || lhs.normalizedText.contains(rhs.normalizedText)
            || rhs.normalizedText.contains(lhs.normalizedText)
        guard sameText else { return false }

        let intersection = lhs.rect.intersection(rhs.rect)
        let minimumArea = min(lhs.rect.width * lhs.rect.height, rhs.rect.width * rhs.rect.height)
        guard minimumArea > 0 else { return false }

        let intersectionRatio = (intersection.width * intersection.height) / minimumArea
        if intersectionRatio >= OCRPolicy.duplicateIntersectionThreshold {
            return true
        }

        let verticalDistance = abs(lhs.midY - rhs.midY)
        let horizontalDistance = abs(lhs.minX - rhs.minX)
        return verticalDistance <= max(lhs.height, rhs.height) * 0.7
            && horizontalDistance <= OCRPolicy.wrapContinuationTolerance
    }

    private static func articleParagraphs(from lines: [OCRLine]) -> [String] {
        guard lines.isEmpty == false else { return [] }

        let sortedLines = lines.sorted {
            if abs($0.midY - $1.midY) > 6 {
                return $0.midY < $1.midY
            }
            return $0.minX < $1.minX
        }

        var paragraphs: [String] = []
        var currentParagraphLines: [OCRLine] = []

        for line in sortedLines {
            guard let previousLine = currentParagraphLines.last else {
                currentParagraphLines = [line]
                continue
            }

            if shouldBreakParagraph(before: line, after: previousLine) {
                if let paragraph = paragraphText(from: currentParagraphLines) {
                    paragraphs.append(paragraph)
                }
                currentParagraphLines = [line]
            } else {
                currentParagraphLines.append(line)
            }
        }

        if let paragraph = paragraphText(from: currentParagraphLines) {
            paragraphs.append(paragraph)
        }

        return paragraphs
    }

    private static func shouldBreakParagraph(before line: OCRLine, after previousLine: OCRLine) -> Bool {
        let verticalGap = line.rect.minY - previousLine.rect.maxY
        let lineHeight = max(previousLine.height, line.height, 1)
        if verticalGap > lineHeight * OCRPolicy.paragraphGapMultiplier {
            return true
        }

        let leftEdgeShift = abs(line.minX - previousLine.minX)
        if leftEdgeShift > OCRPolicy.columnAlignmentTolerance {
            let isLikelyWrappedContinuation = line.minX >= previousLine.minX - OCRPolicy.wrapContinuationTolerance
                && line.minX <= previousLine.maxX
            if isLikelyWrappedContinuation == false {
                return true
            }
        }

        if previousLine.text.hasSuffix(":") {
            return true
        }

        return false
    }

    private static func paragraphText(from lines: [OCRLine]) -> String? {
        guard lines.isEmpty == false else { return nil }

        let orderedLines = lines.sorted {
            if abs($0.midY - $1.midY) > 6 {
                return $0.midY < $1.midY
            }
            return $0.minX < $1.minX
        }

        var segments: [String] = []
        for line in orderedLines {
            let trimmedLine = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.isEmpty == false else { continue }

            if var lastSegment = segments.popLast() {
                if shouldAppendWithoutLineBreak(previous: lastSegment, next: trimmedLine) {
                    lastSegment += continuationSeparator(previous: lastSegment, next: trimmedLine) + trimmedLine
                    segments.append(lastSegment)
                } else {
                    segments.append(lastSegment)
                    segments.append(trimmedLine)
                }
            } else {
                segments.append(trimmedLine)
            }
        }

        let paragraph = segments.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return paragraph.isEmpty ? nil : paragraph
    }

    private static func shouldAppendWithoutLineBreak(previous: String, next: String) -> Bool {
        let previousEndsSentence = previous.hasSuffix(".")
            || previous.hasSuffix("!")
            || previous.hasSuffix("?")
        let nextStartsBullet = next.hasPrefix("•")
            || next.hasPrefix("- ")
            || next.hasPrefix("* ")

        if nextStartsBullet || previousEndsSentence {
            return false
        }

        return true
    }

    private static func continuationSeparator(previous: String, next: String) -> String {
        if previous.hasSuffix("-") {
            return ""
        }

        let nextStartsWithPunctuation = next.first.map {
            CharacterSet.punctuationCharacters.contains($0.unicodeScalars.first!)
        } ?? false
        return nextStartsWithPunctuation ? "" : " "
    }
}
