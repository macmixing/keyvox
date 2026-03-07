import Foundation

public struct WhitespaceNormalizer {
    func normalize(_ text: String, renderMode: ListRenderMode) -> String {
        switch renderMode {
        case .singleLineInline:
            return text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .multiline:
            let normalizedLines = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    String(line)
                        .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

            var collapsedLines: [String] = []
            collapsedLines.reserveCapacity(normalizedLines.count)

            var previousWasBlank = false
            for line in normalizedLines {
                let isBlank = line.isEmpty
                if isBlank {
                    if collapsedLines.isEmpty || previousWasBlank {
                        continue
                    }
                    collapsedLines.append("")
                    previousWasBlank = true
                } else {
                    collapsedLines.append(line)
                    previousWasBlank = false
                }
            }

            while collapsedLines.first?.isEmpty == true {
                collapsedLines.removeFirst()
            }
            while collapsedLines.last?.isEmpty == true {
                collapsedLines.removeLast()
            }

            return collapsedLines.joined(separator: "\n")
        }
    }
}
