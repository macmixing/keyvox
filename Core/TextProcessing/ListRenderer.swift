import Foundation

struct ListRenderer {
    func render(_ list: DetectedList, mode: ListRenderMode) -> String {
        let lines = list.items.map { "\($0.spokenIndex). \($0.content)" }
        let listText: String

        switch mode {
        case .multiline:
            listText = lines.joined(separator: "\n")
        case .singleLineInline:
            listText = lines.joined(separator: "; ")
        }

        let leadIn = formattedLeadIn(list.leadingText)
        let trailing = normalizedTrailingText(list.trailingText)
        var composed = listText

        if !leadIn.isEmpty {
            switch mode {
            case .multiline:
                composed = leadIn + "\n\n" + composed
            case .singleLineInline:
                composed = leadIn + " " + composed
            }
        }

        if !trailing.isEmpty {
            switch mode {
            case .multiline:
                composed += "\n\n" + trailing
            case .singleLineInline:
                composed += " " + trailing
            }
        }

        return composed
    }

    private func formattedLeadIn(_ text: String) -> String {
        var leadIn = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !leadIn.isEmpty else { return "" }

        if leadIn.hasSuffix(":") {
            return leadIn
        }

        leadIn = leadIn.trimmingCharacters(in: CharacterSet(charactersIn: ".,;!?"))
        return leadIn + ":"
    }

    private func normalizedTrailingText(_ text: String) -> String {
        let trailing = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trailing.isEmpty else { return "" }

        let transitionPattern = #"(?i)^(and|then|now|so|because|since|as|also|anyway|anyways|next|finally|after that)\b"#
        guard trailing.range(of: transitionPattern, options: .regularExpression) != nil else {
            return trailing
        }

        return capitalizingFirstLetter(in: trailing)
    }

    private func capitalizingFirstLetter(in text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}
