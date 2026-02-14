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
        let trailing = list.trailingText.trimmingCharacters(in: .whitespacesAndNewlines)
        var composed = listText

        if !leadIn.isEmpty {
            switch mode {
            case .multiline:
                composed = leadIn + "\n" + composed
            case .singleLineInline:
                composed = leadIn + " " + composed
            }
        }

        if !trailing.isEmpty {
            switch mode {
            case .multiline:
                composed += "\n" + trailing
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
}
