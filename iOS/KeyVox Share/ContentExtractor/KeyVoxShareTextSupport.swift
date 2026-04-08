import Foundation
import UniformTypeIdentifiers

enum KeyVoxShareTextSupport {
    static func normalizeText(from item: NSSecureCoding?) -> String? {
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

    static func normalizeText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedComparisonText(for text: String) -> String? {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted.union(.whitespacesAndNewlines))

        return folded.isEmpty ? nil : folded
    }

    static func joinedText(from segments: [String]) -> String {
        segments
            .compactMap(normalizeText(_:))
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func appendIfDistinct(_ text: String, to segments: inout [String], seenComparisons: inout Set<String>) {
        guard let normalized = normalizeText(text),
              let comparison = normalizedComparisonText(for: normalized),
              seenComparisons.contains(comparison) == false else {
            return
        }

        seenComparisons.insert(comparison)
        segments.append(normalized)
    }
}

enum KeyVoxShareDirectTextExtractor {
    private static let supportedTypeIdentifiers = [
        UTType.plainText.identifier,
        UTType.text.identifier,
        UTType.utf8PlainText.identifier
    ]

    static func extractText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []
        var seenComparisons: Set<String> = []

        for item in items {
            if let attributedString = item.attributedContentText?.string,
               let normalized = KeyVoxShareTextSupport.normalizeText(attributedString) {
                KeyVoxShareContentExtractorDiagnostics.log("Found attributedContentText length=\(normalized.count).")
                KeyVoxShareTextSupport.appendIfDistinct(
                    normalized,
                    to: &segments,
                    seenComparisons: &seenComparisons
                )
            }

            for provider in item.attachments ?? [] {
                if let text = await loadText(from: provider) {
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

    private static func loadText(from provider: NSItemProvider) async -> String? {
        for typeIdentifier in supportedTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            do {
                KeyVoxShareContentExtractorDiagnostics.log("Attempting direct text load for type=\(typeIdentifier).")
                let item = try await KeyVoxShareImageItemLoader.loadItem(from: provider, typeIdentifier: typeIdentifier)
                if let text = KeyVoxShareTextSupport.normalizeText(from: item) {
                    KeyVoxShareContentExtractorDiagnostics.log(
                        "Loaded direct text length=\(text.count) for type=\(typeIdentifier)."
                    )
                    return text
                }
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Direct text load failed for type=\(typeIdentifier): \(error.localizedDescription)"
                )
            }
        }

        return nil
    }
}
