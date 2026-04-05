import Foundation
import UniformTypeIdentifiers
import SwiftSoup

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
                        
                        let cleanedHTML = cleanHTML(from: htmlString)
                        let normalized = KeyVoxShareTextSupport.normalizeText(cleanedHTML)
                        KeyVoxShareContentExtractorDiagnostics.log("Successfully fetched snapshot length=\(normalized?.count ?? 0)")
                        return normalized
                    }
                    
                    KeyVoxShareContentExtractorDiagnostics.log("Failed to fetch full HTML snapshot from URL.")
                    return nil
                }
                
                // If it's pure HTML payload or web archive
                if let text = KeyVoxShareTextSupport.normalizeText(from: item) {
                    let sanitizedText = cleanHTML(from: text)
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

    private static func cleanHTML(from htmlString: String) -> String {
        do {
            let doc = try SwiftSoup.parse(htmlString)
            
            // Blast away "noise" containers that clutter TTS
            // These rarely contain the primary article text
            try doc.select("nav, footer, aside, header, script, style, svg, noscript, iframe, .ads, .sidebar, .menu, .nav").remove()
            
            // Intelligent Pacing: Add extra breaks after headlines and list items
            // This ensures a natural pause in TTS instead of rushing through paragraphs
            for element in try doc.select("h1, h2, h3, h4, h5, h6, li, p") {
                try element.after("\n")
            }
            
            // Extract metadata for the intro
            let metadataPrefix = extractMetadataIntro(from: doc)
            
            // Extract the body text - SwiftSoup does a great job of respecting 
            // display properties and block-level separations
            let bodyText = try doc.body()?.text() ?? ""
            let combinedText = metadataPrefix.isEmpty ? bodyText : (metadataPrefix + "\n\n" + bodyText)
            
            // Final polish: handle entity decoding and whitespace collapse
            return polishText(combinedText)
        } catch {
            KeyVoxShareContentExtractorDiagnostics.log("SwiftSoup parsing failed, falling back to basic strip.")
            return basicStripHTML(from: htmlString)
        }
    }

    private static func extractMetadataIntro(from doc: Document) -> String {
        do {
            let title = try doc.title()
            let author = try doc.select("meta[name=author], meta[property='article:author'], meta[name='twitter:creator']").attr("content")
            
            if !title.isEmpty {
                return author.isEmpty ? "Reading: \(title)" : "Reading: \(title), by \(author)"
            }
        } catch {
            KeyVoxShareContentExtractorDiagnostics.log("Failed to extract metadata: \(error.localizedDescription)")
        }
        return ""
    }

    private static func polishText(_ text: String) -> String {
        var polished = text
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Final safety check for remaining entity issues
        polished = polished.replacingOccurrences(of: "&nbsp;", with: " ")
        return polished
    }

    private static func basicStripHTML(from htmlString: String) -> String {
        // Fallback lightweight regex if SwiftSoup fails
        var text = htmlString
        text = text.replacingOccurrences(of: "(?is)<(style|script|svg|aside|footer|nav).*?>.*?</\\1>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
