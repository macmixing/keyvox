import Foundation
import UniformTypeIdentifiers

enum KeyVoxShareWebExtractor {
    private static let supportedTypeIdentifiers = [
        UTType.html.identifier,
        UTType.webArchive.identifier,
        UTType.url.identifier
    ]

    static func extractText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await loadWebText(from: provider) {
                    segments.append(text)
                }
            }
        }

        return KeyVoxShareTextSupport.joinedText(from: segments)
    }

    private static func loadWebText(from provider: NSItemProvider) async -> String? {
        for typeIdentifier in supportedTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            do {
                KeyVoxShareContentExtractorDiagnostics.log("Attempting web text load for type=\(typeIdentifier).")
                let item = try await KeyVoxShareImageItemLoader.loadItem(from: provider, typeIdentifier: typeIdentifier)
                
                // Handle async URL fetching
                if let url = item as? URL, url.scheme == "http" || url.scheme == "https" {
                    KeyVoxShareContentExtractorDiagnostics.log("Fetching full HTML snapshot from URL: \(url.absoluteString)")
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10.0
                    
                    if let (data, response) = try? await URLSession.shared.data(for: request),
                       let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let htmlString = String(data: data, encoding: .utf8) {
                        
                        let cleanedHTML = stripHTML(from: htmlString)
                        let normalized = KeyVoxShareTextSupport.normalizeText(cleanedHTML)
                        KeyVoxShareContentExtractorDiagnostics.log("Successfully fetched snapshot length=\(normalized?.count ?? 0)")
                        return normalized
                    }
                    
                    KeyVoxShareContentExtractorDiagnostics.log("Failed to fetch full HTML snapshot from URL.")
                    return nil
                }
                
                // If it's pure HTML payload or web archive
                if let text = KeyVoxShareTextSupport.normalizeText(from: item) {
                    let sanitizedText = stripHTML(from: text)
                    if let finalNormalized = KeyVoxShareTextSupport.normalizeText(sanitizedText) {
                        KeyVoxShareContentExtractorDiagnostics.log(
                            "Loaded web payload length=\(finalNormalized.count) for type=\(typeIdentifier)."
                        )
                        return finalNormalized
                    }
                }
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Web text load failed for type=\(typeIdentifier): \(error.localizedDescription)"
                )
            }
        }

        return nil
    }

    private static func stripHTML(from htmlString: String) -> String {
        var text = htmlString
        // Remove style, script, svg and comments completely
        text = text.replacingOccurrences(of: "(?is)<style.*?>.*?</style>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<script.*?>.*?</script>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<svg.*?>.*?</svg>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<!--.*?-->", with: " ", options: .regularExpression)
        
        // Add newlines for block elements
        text = text.replacingOccurrences(of: "(?i)<(div|p|br|h[1-6]|li|tr|article|section|header|footer|aside|nav)[^>]*>", with: "\n", options: .regularExpression)
        
        // Remove all remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Unescape common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&#8211;", with: "-")
        text = text.replacingOccurrences(of: "&#8212;", with: "--")
        text = text.replacingOccurrences(of: "&#8216;", with: "'")
        text = text.replacingOccurrences(of: "&#8217;", with: "'")
        text = text.replacingOccurrences(of: "&#8220;", with: "\"")
        text = text.replacingOccurrences(of: "&#8221;", with: "\"")
        
        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text
    }
}
