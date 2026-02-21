import Foundation

struct ListPatternRunSelector {
    func selectDetection(
        from markers: [ListPatternMarker],
        in text: String,
        languageCode: String?
    ) -> (run: [ListPatternMarker], renumberSequentially: Bool)? {
        if let bestRun = bestMonotonicRun(from: markers, in: text, languageCode: languageCode), bestRun.count >= 2 {
            return (bestRun, false)
        }
        if let restartedRun = restartedOneRunAcrossParagraphBreaks(from: markers, in: text),
           restartedRun.count >= 2 {
            return (restartedRun, true)
        }
        return nil
    }

    private func bestMonotonicRun(
        from markers: [ListPatternMarker],
        in text: String,
        languageCode: String?
    ) -> [ListPatternMarker]? {
        guard !markers.isEmpty else { return nil }
        let nsText = text as NSString

        // Build best monotonic subsequence ending at each marker, so we can
        // skip noise markers (e.g. incidental "one" in prose) and still keep
        // the intended 1->2->3 list flow.
        var bestEndingAt = Array(repeating: [ListPatternMarker](), count: markers.count)

        for i in markers.indices {
            var bestForCurrent: [ListPatternMarker] = [markers[i]]
            for j in 0..<i where markers[i].number > markers[j].number {
                let previousRun = bestEndingAt[j]
                guard !previousRun.isEmpty else { continue }
                let candidate = previousRun + [markers[i]]
                if shouldPrefer(run: candidate, over: bestForCurrent, in: nsText, languageCode: languageCode) {
                    bestForCurrent = candidate
                }
            }
            bestEndingAt[i] = bestForCurrent
        }

        var best: [ListPatternMarker] = []
        for run in bestEndingAt where shouldPrefer(run: run, over: best, in: nsText, languageCode: languageCode) {
            best = run
        }

        guard best.count >= 2 else { return nil }
        guard isCredibleRunStart(run: best, in: nsText) else { return nil }
        guard isCredibleTwoItemGap(run: best, in: nsText, languageCode: languageCode) else { return nil }
        return best
    }

    // Runs that start above "1" are far more likely to be incidental prose
    // (e.g. "step 3") unless the first marker starts at a strong boundary.
    private func isCredibleRunStart(run: [ListPatternMarker], in nsText: NSString) -> Bool {
        guard let first = run.first else { return false }
        guard first.number > 1 else { return true }
        return markerHasBoundaryBefore(first, in: nsText)
    }

    // Prevent prose like "one for X and three for Y" from being detected as a
    // two-item list while still allowing explicit skipped numbering ("1. ... 3. ...").
    private func isCredibleTwoItemGap(
        run: [ListPatternMarker],
        in nsText: NSString,
        languageCode: String?
    ) -> Bool {
        guard run.count == 2 else { return true }
        if run[0].number > 1 && !run.allSatisfy({ markerHasExplicitDelimiter($0, in: nsText, languageCode: languageCode) }) {
            return false
        }
        let delta = run[1].number - run[0].number
        guard delta > 1 else { return true }
        return run.allSatisfy { markerHasExplicitDelimiter($0, in: nsText, languageCode: languageCode) }
    }

    private func shouldPrefer(
        run candidate: [ListPatternMarker],
        over existing: [ListPatternMarker],
        in nsText: NSString,
        languageCode: String?
    ) -> Bool {
        guard !candidate.isEmpty else { return false }
        guard !existing.isEmpty else { return true }

        if candidate.count != existing.count {
            return candidate.count > existing.count
        }

        let candidateStrength = runStrength(candidate, in: nsText, languageCode: languageCode)
        let existingStrength = runStrength(existing, in: nsText, languageCode: languageCode)
        if candidateStrength != existingStrength {
            return candidateStrength > existingStrength
        }

        let candidateStart = candidate.first?.markerTokenStart ?? 0
        let existingStart = existing.first?.markerTokenStart ?? 0
        return candidateStart > existingStart
    }

    private func runStrength(_ run: [ListPatternMarker], in nsText: NSString, languageCode: String?) -> Int {
        guard !run.isEmpty else { return 0 }

        var score = run.reduce(0) { partial, marker in
            var score = partial
            if markerHasExplicitDelimiter(marker, in: nsText, languageCode: languageCode) { score += 2 }
            if markerHasBoundaryBefore(marker, in: nsText) { score += 1 }
            return score
        }

        // Prefer naturally contiguous counting while still allowing skipped
        // numbers (e.g. 1, 2, 4) so later markers remain list items.
        for index in 1..<run.count {
            let delta = run[index].number - run[index - 1].number
            if delta == 1 {
                score += 2
            } else if delta == 2 {
                score += 1
            }
        }

        return score
    }

    private func markerHasExplicitDelimiter(
        _ marker: ListPatternMarker,
        in nsText: NSString,
        languageCode: String?
    ) -> Bool {
        let spanLength = max(0, marker.contentStart - marker.markerTokenStart)
        guard spanLength > 0 else { return false }
        let span = nsText.substring(with: NSRange(location: marker.markerTokenStart, length: spanLength))
        return ListPatternMarkerParser.hasExplicitDelimitedMarkerPrefix(in: span, languageCode: languageCode)
    }

    private func markerHasBoundaryBefore(_ marker: ListPatternMarker, in nsText: NSString) -> Bool {
        guard marker.markerTokenStart > 0 else { return true }
        let prefix = nsText.substring(to: marker.markerTokenStart)
        let boundaryPattern = #"(?:^|[\n\r]|[.!?:;])\s*$"#
        return prefix.range(of: boundaryPattern, options: .regularExpression) != nil
    }

    // Paragraph chunking can restart list numbering context between chunks
    // (e.g. "one ...", "one ...", "one ..."). Recover list intent only when
    // those restarts are separated by explicit paragraph breaks.
    private func restartedOneRunAcrossParagraphBreaks(from markers: [ListPatternMarker], in text: String) -> [ListPatternMarker]? {
        guard markers.count >= 2 else { return nil }
        let nsText = text as NSString

        var best: [ListPatternMarker] = []
        var current: [ListPatternMarker] = []

        for marker in markers {
            guard marker.number == 1 else {
                if current.count > best.count { best = current }
                current = []
                continue
            }

            guard let previous = current.last else {
                current = [marker]
                continue
            }

            let gapStart = previous.contentStart
            let gapLength = max(0, marker.markerTokenStart - gapStart)
            let gap = nsText.substring(with: NSRange(location: gapStart, length: gapLength))
            if gap.contains("\n\n") {
                current.append(marker)
            } else {
                if current.count > best.count { best = current }
                current = [marker]
            }
        }

        if current.count > best.count {
            best = current
        }

        return best.count >= 2 ? best : nil
    }
}
