import Foundation
import UniformTypeIdentifiers
import Vision

enum KeyVoxShareContentExtractor {
    static func extractText(from extensionContext: NSExtensionContext?) async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        let directText = await extractDirectText(from: items)
        if directText.isEmpty == false {
            return directText
        }

        let recognizedText = await extractRecognizedText(from: items)
        if recognizedText.isEmpty == false {
            return recognizedText
        }

        return nil
    }

    private static func extractDirectText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []

        for item in items {
            if let attributedString = item.attributedContentText?.string,
               let normalized = normalizeText(attributedString) {
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
                let item = try await loadItem(from: provider, typeIdentifier: typeIdentifier)
                if let text = normalizeText(from: item) {
                    return text
                }
            } catch {
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
            let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.image.identifier)
            return try recognizeText(in: data)
        } catch {
            return nil
        }
    }

    private static func recognizeText(in imageData: Data) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(data: imageData)
        try handler.perform([request])

        let recognizedStrings = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }

        let normalized = joinedText(from: recognizedStrings)
        return normalized.isEmpty ? nil : normalized
    }

    private static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: item as? NSSecureCoding)
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
