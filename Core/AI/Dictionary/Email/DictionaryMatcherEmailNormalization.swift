import Foundation

extension DictionaryMatcher {
    private static let spokenEmailCandidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(^|[^A-Za-z0-9._%+\\-])([A-Za-z0-9._%+'\\-]+(?:[ \\t]+[A-Za-z0-9._%+'\\-]+)*)[ \\t]+at[ \\t]+([A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+)(?=$|[^A-Za-z0-9\\-])",
        options: [.caseInsensitive]
    )
    private static let compactSpokenEmailCandidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(^|[^A-Za-z0-9._%+\\-])([A-Za-z0-9._%+'\\-]{2,})at([A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+)(?=$|[^A-Za-z0-9\\-])",
        options: [.caseInsensitive]
    )
    private static let literalEmailCandidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?<![A-Za-z0-9._%+\\-])([A-Z0-9._%+\\-]+)@([A-Z0-9.\\-]+\\.[A-Z]{2,})",
        options: [.caseInsensitive]
    )

    func normalizeEmailsUsingDictionary(in input: String) -> String {
        guard !input.isEmpty, !emailEntriesByDomain.isEmpty else { return input }
        #if DEBUG
        logEmailNormalization(
            "start domainCount=\(emailEntriesByDomain.count) input=\(debugTextSummary(input))"
        )
        #endif

        var output = input
        output = applyUntilStable(output, using: replaceSpokenEmailCandidates(in:))
        output = applyUntilStable(output, using: replaceCompactEmailCandidates(in:))
        output = applyUntilStable(output, using: replaceLiteralEmailCandidates(in:))
        #if DEBUG
        logEmailNormalization("end output=\(debugTextSummary(output))")
        #endif
        return output
    }

    private func applyUntilStable(_ text: String, using transform: (String) -> String) -> String {
        var current = text
        while true {
            let next = transform(current)
            guard next != current else { return current }
            current = next
        }
    }

    private func replaceSpokenEmailCandidates(in text: String) -> String {
        guard let regex = Self.spokenEmailCandidateRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        #if DEBUG
        logEmailNormalization("spoken matches=\(matches.count) text=\(debugTextSummary(text))")
        #endif
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let boundary = nsText.substring(with: match.range(at: 1))
            let localRawOriginal = nsText.substring(with: match.range(at: 2))
            let domainRaw = nsText.substring(with: match.range(at: 3))
            #if DEBUG
            logEmailNormalization(
                "spoken candidate local=\(debugTokenSummary(localRawOriginal)) domain=\(debugDomainSummary(domainRaw)) boundary=\(debugBoundarySummary(boundary))"
            )
            #endif
            let attachedMarker = extractAttachedListMarker(from: localRawOriginal, boundary: boundary)
            let localRaw = attachedMarker?.local ?? localRawOriginal
            guard let domainResolution = resolveDictionaryDomainCandidate(domainRaw) else {
                #if DEBUG
                logEmailNormalization("spoken reject reason=domain_resolve_failed domain=\(debugDomainSummary(domainRaw))")
                #endif
                continue
            }
            let domain = domainResolution.domain
            guard let resolved = resolveSpokenEmail(localRaw: localRaw, domain: domain) else {
                #if DEBUG
                logEmailNormalization(
                    "spoken reject reason=resolve_failed local=\(debugTokenSummary(localRaw)) domain=\(debugDomainSummary(domain))"
                )
                #endif
                continue
            }

            let markerPrefix = attachedMarker.map { "\($0.marker) " } ?? ""
            let prefix = resolved.prefix.isEmpty ? "" : "\(resolved.prefix) "
            let overflowSuffix = domainResolution.overflow.isEmpty ? "" : " \(domainResolution.overflow)"
            #if DEBUG
            logEmailNormalization(
                "spoken replace local=\(debugTokenSummary(localRaw)) domain=\(debugDomainSummary(domain)) overflowWords=\(wordCount(domainResolution.overflow)) replacementDomain=\(debugDomainSummary(resolved.entry.domain))"
            )
            #endif
            mutable.replaceCharacters(
                in: match.range,
                with: boundary + markerPrefix + prefix + resolved.entry.canonical + overflowSuffix
            )
        }

        return mutable as String
    }

    private func replaceCompactEmailCandidates(in text: String) -> String {
        guard let regex = Self.compactSpokenEmailCandidateRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        #if DEBUG
        logEmailNormalization("compact matches=\(matches.count) text=\(debugTextSummary(text))")
        #endif
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let boundary = nsText.substring(with: match.range(at: 1))
            let localRaw = normalizeLocal(nsText.substring(with: match.range(at: 2)))
            let domainRaw = nsText.substring(with: match.range(at: 3))
            guard let domainResolution = resolveDictionaryDomainCandidate(domainRaw) else {
                #if DEBUG
                logEmailNormalization("compact reject reason=domain_resolve_failed domain=\(debugDomainSummary(domainRaw))")
                #endif
                continue
            }
            let domain = domainResolution.domain
            guard let entry = resolveEntry(local: localRaw, domain: domain) else {
                #if DEBUG
                logEmailNormalization("compact reject reason=resolve_failed local=\(debugTokenSummary(localRaw)) domain=\(debugDomainSummary(domain))")
                #endif
                continue
            }

            let overflowSuffix = domainResolution.overflow.isEmpty ? "" : " \(domainResolution.overflow)"
            #if DEBUG
            logEmailNormalization(
                "compact replace local=\(debugTokenSummary(localRaw)) domain=\(debugDomainSummary(domain)) overflowWords=\(wordCount(domainResolution.overflow)) replacementDomain=\(debugDomainSummary(entry.domain))"
            )
            #endif
            mutable.replaceCharacters(in: match.range, with: boundary + entry.canonical + overflowSuffix)
        }

        return mutable as String
    }

    private func replaceLiteralEmailCandidates(in text: String) -> String {
        guard let regex = Self.literalEmailCandidateRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        #if DEBUG
        logEmailNormalization("literal matches=\(matches.count) text=\(debugTextSummary(text))")
        #endif
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let localRawOriginal = nsText.substring(with: match.range(at: 1))
            let domainRaw = nsText.substring(with: match.range(at: 2))
            guard let domainResolution = resolveDictionaryDomainCandidate(domainRaw) else {
                #if DEBUG
                logEmailNormalization("literal reject reason=domain_resolve_failed domain=\(debugDomainSummary(domainRaw))")
                #endif
                continue
            }
            let domain = domainResolution.domain

            let localRaw = normalizeLocal(localRawOriginal)
            guard let resolved = resolveLiteralEmail(localRaw: localRaw, localOriginal: localRawOriginal, domain: domain) else {
                #if DEBUG
                logEmailNormalization(
                    "literal reject reason=resolve_failed local=\(debugTokenSummary(localRaw)) localOriginal=\(debugTokenSummary(localRawOriginal)) domain=\(debugDomainSummary(domain))"
                )
                #endif
                continue
            }

            let replacement = resolved.prefix.isEmpty
                ? resolved.entry.canonical
                : "\(resolved.prefix) \(resolved.entry.canonical)"
            let replacementWithOverflow = domainResolution.overflow.isEmpty
                ? replacement
                : "\(replacement) \(domainResolution.overflow)"
            #if DEBUG
            logEmailNormalization(
                "literal replace local=\(debugTokenSummary(localRaw)) domain=\(debugDomainSummary(domain)) overflowWords=\(wordCount(domainResolution.overflow)) replacement=\(debugTextSummary(replacementWithOverflow))"
            )
            #endif
            mutable.replaceCharacters(in: match.range, with: replacementWithOverflow)
        }

        return mutable as String
    }

    #if DEBUG
    private func logEmailNormalization(_ message: String) {
        print("[KVXEmailNorm] \(message)")
    }

    private var rawDebugTextLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
    }

    private func debugTextSummary(_ text: String) -> String {
        let chars = text.count
        let words = wordCount(text)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let atSigns = text.filter { $0 == "@" }.count
        let dots = text.filter { $0 == "." }.count
        if rawDebugTextLoggingEnabled {
            let escaped = truncatedDebugEscaped(text, maxCharacters: 220)
            return "chars=\(chars) words=\(words) lines=\(lines) at=\(atSigns) dots=\(dots) text=\(escaped)"
        }
        return "chars=\(chars) words=\(words) lines=\(lines) at=\(atSigns) dots=\(dots)"
    }

    private func debugTokenSummary(_ token: String) -> String {
        let chars = token.count
        let words = wordCount(token)
        let dots = token.filter { $0 == "." }.count
        let atSigns = token.filter { $0 == "@" }.count
        if rawDebugTextLoggingEnabled {
            return "chars=\(chars) words=\(words) dots=\(dots) at=\(atSigns) token=\(truncatedDebugEscaped(token, maxCharacters: 120))"
        }
        return "chars=\(chars) words=\(words) dots=\(dots) at=\(atSigns)"
    }

    private func debugDomainSummary(_ domain: String) -> String {
        let normalized = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let labels = normalized.split(separator: ".")
        let tldLength = labels.last?.count ?? 0
        if rawDebugTextLoggingEnabled {
            return "chars=\(normalized.count) labels=\(labels.count) tldLen=\(tldLength) domain=\(truncatedDebugEscaped(normalized, maxCharacters: 120))"
        }
        return "chars=\(normalized.count) labels=\(labels.count) tldLen=\(tldLength)"
    }

    private func debugBoundarySummary(_ boundary: String) -> String {
        if boundary.isEmpty { return "empty" }
        if boundary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "whitespace" }
        return rawDebugTextLoggingEnabled
            ? "punct(\(truncatedDebugEscaped(boundary, maxCharacters: 20)))"
            : "punct"
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func truncatedDebugEscaped(_ text: String, maxCharacters: Int) -> String {
        let escaped = text.replacingOccurrences(of: "\n", with: "\\n")
        guard escaped.count > maxCharacters else { return escaped }
        let end = escaped.index(escaped.startIndex, offsetBy: maxCharacters)
        return "\(escaped[..<end])..."
    }
    #endif
}
