import Foundation
import UniformTypeIdentifiers

enum KeyVoxShareTextSupport {
    private enum ReflowPolicy {
        static let paragraphTerminalLineRatio = 0.72
    }

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

    static func reflowSoftLineBreaks(_ text: String) -> String? {
        let normalizedLineEndings = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedLineEndings.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var currentLines: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                appendReflowedParagraph(from: currentLines, to: &paragraphs)
                currentLines.removeAll()
            } else {
                if shouldStartNewParagraph(before: trimmedLine, currentLines: currentLines) {
                    appendReflowedParagraph(from: currentLines, to: &paragraphs)
                    currentLines.removeAll()
                }
                currentLines.append(trimmedLine)
            }
        }

        appendReflowedParagraph(from: currentLines, to: &paragraphs)
        return normalizeText(paragraphs.joined(separator: "\n\n"))
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

    private static func appendReflowedParagraph(from lines: [String], to paragraphs: inout [String]) {
        let paragraph = reflowedParagraph(from: lines)
        if paragraph.isEmpty == false {
            paragraphs.append(paragraph)
        }
    }

    private static func reflowedParagraph(from lines: [String]) -> String {
        var segments: [String] = []

        for line in lines {
            if shouldPreserveLineBreak(before: line, existingSegments: segments) {
                segments.append(line)
                continue
            }

            if var previous = segments.popLast() {
                if previous.hasSuffix("-") {
                    previous.removeLast()
                    segments.append(previous + line)
                } else {
                    segments.append(previous + " " + line)
                }
            } else {
                segments.append(line)
            }
        }

        return segments.joined(separator: "\n")
    }

    private static func shouldPreserveLineBreak(before line: String, existingSegments: [String]) -> Bool {
        guard existingSegments.isEmpty == false else { return false }
        return isListItemLine(line)
    }

    private static func shouldStartNewParagraph(before line: String, currentLines: [String]) -> Bool {
        guard let previousLine = currentLines.last else { return false }
        if isListItemLine(line) {
            return true
        }

        guard hasTerminalPunctuation(previousLine) else {
            return false
        }

        if startsLikeParagraphLead(line) {
            return true
        }

        let maximumLineLength = currentLines.map(\.count).max() ?? previousLine.count
        guard maximumLineLength > 0 else { return false }

        let terminalLineRatio = Double(previousLine.count) / Double(maximumLineLength)
        return terminalLineRatio <= ReflowPolicy.paragraphTerminalLineRatio
    }

    private static func hasTerminalPunctuation(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastCharacter = trimmed.last else { return false }
        return ".!?".contains(lastCharacter)
    }

    private static func startsLikeParagraphLead(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstScalar = trimmed.firstMeaningfulLeadingScalar else { return false }
        return CharacterSet.uppercaseLetters.contains(firstScalar)
            || CharacterSet.decimalDigits.contains(firstScalar)
    }

    private static func isListItemLine(_ line: String) -> Bool {
        line.hasPrefix("• ")
            || line.hasPrefix("- ")
            || line.hasPrefix("* ")
    }
}

private extension String {
    var firstMeaningfulLeadingScalar: UnicodeScalar? {
        let ignoredLeadingCharacters = CharacterSet(charactersIn: "\"'([")
        for scalar in unicodeScalars {
            if ignoredLeadingCharacters.contains(scalar) == false {
                return scalar
            }
        }

        return nil
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
                let item = try await KeyVoxShareItemProviderLoader.loadItem(
                    from: provider,
                    typeIdentifier: typeIdentifier
                )
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
