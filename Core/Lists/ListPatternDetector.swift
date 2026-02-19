import Foundation

struct ListPatternDetector {
    private let markerParser = ListPatternMarkerParser()
    private let runSelector = ListPatternRunSelector()
    private let trailingSplitter = ListPatternTrailingSplitter()

    func detectList(in text: String) -> DetectedList? {
        let markers = markerParser.markers(in: text)
        #if DEBUG
        logDetector("markers=\(debugMarkers(markers)) text=\(debugTextSummary(text))")
        #endif
        guard markers.count >= 2 else {
            #if DEBUG
            logDetector("reject reason=insufficient_markers count=\(markers.count)")
            #endif
            return nil
        }
        guard let detection = runSelector.selectDetection(from: markers, in: text) else {
            #if DEBUG
            logDetector("reject reason=no_monotonic_run")
            #endif
            return nil
        }

        let bestRun = detection.run
        let nsText = text as NSString
        let firstMarkerStart = bestRun[0].markerTokenStart
        var items: [DetectedListItem] = []
        var trailingText = ""

        for index in 0..<bestRun.count {
            let marker = bestRun[index]
            let end = index + 1 < bestRun.count ? bestRun[index + 1].markerTokenStart : nsText.length
            guard end > marker.contentStart else {
                #if DEBUG
                logDetector("reject reason=invalid_marker_span markerStart=\(marker.markerTokenStart) contentStart=\(marker.contentStart) end=\(end)")
                #endif
                return nil
            }

            let rawContent = nsText.substring(with: NSRange(location: marker.contentStart, length: end - marker.contentStart))
            let content: String
            if index == bestRun.count - 1 {
                let split = trailingSplitter.splitLastItemAndTrailing(rawContent)
                guard let cleanedItem = sanitizeItemContent(split.itemText) else {
                    #if DEBUG
                    logDetector("reject reason=last_item_sanitize_failed item=\(debugTextSummary(split.itemText))")
                    #endif
                    return nil
                }
                content = cleanedItem
                trailingText = split.trailingText
            } else {
                guard let cleanedItem = sanitizeItemContent(rawContent) else {
                    #if DEBUG
                    logDetector("reject reason=item_sanitize_failed item=\(debugTextSummary(rawContent))")
                    #endif
                    return nil
                }
                content = cleanedItem
            }
            let spokenIndex = detection.renumberSequentially ? (index + 1) : marker.number
            items.append(DetectedListItem(spokenIndex: spokenIndex, content: content))
        }

        guard items.count >= 2 else {
            #if DEBUG
            logDetector("reject reason=insufficient_items count=\(items.count)")
            #endif
            return nil
        }
        let leadingText = nsText
            .substring(to: max(0, firstMarkerStart))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        let itemSummary = items
            .map { "\($0.spokenIndex){chars=\($0.content.count),words=\($0.content.split(whereSeparator: \.isWhitespace).count)}" }
            .joined(separator: ",")
        logDetector(
            "accept renumberSequentially=\(detection.renumberSequentially) " +
            "leading=\(debugTextSummary(leadingText)) " +
            "items=[\(itemSummary)] " +
            "trailing=\(debugTextSummary(trailingText))"
        )
        #endif

        return DetectedList(leadingText: leadingText, items: items, trailingText: trailingText)
    }

    private func sanitizeItemContent(_ raw: String) -> String? {
        var cleaned = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleaned = cleaned
            .replacingOccurrences(of: "^(?i)(and|then|next)\\b[\\s,:-]*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)[\\s,:-]*(and|then|next)$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleaned = stripTerminalPunctuation(in: cleaned)

        guard cleaned.count >= 2 else { return nil }
        guard cleaned.rangeOfCharacter(from: .letters) != nil else { return nil }

        if let normalizedDomainItem = WebsiteNormalizer.normalizeLeadingDomainTokenCasing(in: cleaned) {
            return normalizedDomainItem
        }

        return capitalizeFirstLetter(in: cleaned)
    }

    private func stripTerminalPunctuation(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"[\"'”’\)\]\}]*[.,;:!?…]+[\"'”’\)\]\}]*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capitalizeFirstLetter(in text: String) -> String {
        guard let firstLetter = text.firstIndex(where: { $0.isLetter }) else { return text }
        var capitalized = text
        capitalized.replaceSubrange(firstLetter...firstLetter, with: String(text[firstLetter]).uppercased())
        return capitalized
    }

    #if DEBUG
    private func debugMarkers(_ markers: [ListPatternMarker]) -> String {
        markers
            .map { "{n:\($0.number),start:\($0.markerTokenStart),content:\($0.contentStart)}" }
            .joined(separator: ",")
    }

    private func debugTextSummary(_ text: String) -> String {
        let chars = text.count
        let words = text.split(whereSeparator: \.isWhitespace).count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return "chars=\(chars) words=\(words) lines=\(lines)"
    }

    private func logDetector(_ message: String) {
        print("[KVXListDetector] \(message)")
    }
    #endif
}
