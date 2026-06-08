import Foundation

enum NumberEvidence {
    enum Component: Equatable {
        case value(Int)
        case separator
    }

    static func components(in tokens: [RepairWordToken]) -> [Component]? {
        guard !tokens.isEmpty else { return nil }

        let tokenText = tokens.map(\.text).joined(separator: " ")
        if let value = RepairNumberParsing.parsedSpellOutNumberPhrase(tokenText) {
            return [.value(value)]
        }

        var components: [Component] = []
        for token in tokens {
            if RepairNumberParsing.isSpellOutDecimalSeparator(token) {
                components.append(.separator)
            } else if let value = RepairNumberParsing.numericValue(for: token) {
                components.append(.value(value))
            } else {
                return nil
            }
        }

        return components
    }

    static func parsedValue(in tokens: [RepairWordToken]) -> Int? {
        let texts = tokens.map(\.text)
        if texts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return Int(texts.joined())
        }
        if let numberPhrase = RepairNumberParsing.parsedSpellOutNumberPhrase(texts.joined(separator: " ")) {
            return numberPhrase
        }
        if let chunkedNumberPhrase = RepairNumberParsing.parsedSpellOutNumberPhraseByChunks(texts.joined(separator: " ")) {
            return chunkedNumberPhrase
        }
        if let digitSequence = RepairNumberParsing.parsedDigitSequence(from: texts) {
            return digitSequence
        }
        return RepairNumberParsing.parsedSpellOutInteger(texts.joined(separator: " "))
    }

    static func isEquivalent(
        _ leftEvidence: [Component],
        _ rightEvidence: [Component],
        leftRun: [RepairWordToken],
        rightRun: [RepairWordToken],
        leftText: String,
        rightText: String
    ) -> Bool {
        if leftEvidence == rightEvidence {
            return true
        }

        let leftAlternatives = alternatives(leftEvidence, tokens: leftRun, in: leftText)
        let rightAlternatives = alternatives(rightEvidence, tokens: rightRun, in: rightText)
        return !leftAlternatives.isDisjoint(with: rightAlternatives)
    }

    static func canonicalReplacementText(
        evidence: [Component],
        tokens: [RepairWordToken],
        sourceText: String,
        sourceRange: Range<String.Index>
    ) -> String {
        if tokens.count > 1,
           evidence.count == 1,
           case let .value(value) = evidence[0] {
            return String(value)
        }

        return String(sourceText[sourceRange])
    }

    private static func alternatives(
        _ evidence: [Component],
        tokens: [RepairWordToken],
        in text: String
    ) -> Set<String> {
        var alternatives: Set<String> = []

        let values = evidence.compactMap { component -> Int? in
            if case let .value(value) = component {
                return value
            }
            return nil
        }
        if values.count == evidence.count {
            alternatives.insert(values.map(String.init).joined())
            alternatives.formUnion(groupedNumberAlternatives(values))
        }

        if evidence.contains(.separator) {
            var parts: [String] = []
            for component in evidence {
                switch component {
                case let .value(value):
                    parts.append(String(value))
                case .separator:
                    parts.append(".")
                }
            }
            alternatives.insert(parts.joined())
        }

        let range = tokens[0].range.lowerBound..<tokens[tokens.count - 1].range.upperBound
        let runText = String(text[range])
        if let wholeRunValue = RepairNumberParsing.parsedSpellOutInteger(runText) {
            alternatives.insert(String(wholeRunValue))
        }
        if let digitSequence = RepairNumberParsing.parsedDigitSequence(from: tokens.map(\.text)) {
            alternatives.insert(String(digitSequence))
        }

        let literal = text[range].map { character -> Character in
            character.isNumber ? character : "."
        }
        alternatives.insert(String(literal).split(separator: ".").joined(separator: "."))

        return alternatives
    }

    private static func groupedNumberAlternatives(_ values: [Int]) -> Set<String> {
        guard !values.isEmpty else { return [] }

        var alternatives: Set<String> = []
        func collect(index: Int, groups: [Int]) {
            if index == values.count {
                alternatives.insert(groups.map(String.init).joined())
                return
            }

            collect(index: index + 1, groups: groups + [values[index]])

            let nextIndex = index + 1
            if nextIndex < values.count,
               values[index].isMultiple(of: RepairNumberParsing.apStyleNumeralLowerBound),
               values[index] >= RepairNumberParsing.apStyleNumeralLowerBound,
               values[index] < RepairNumberParsing.apStyleNumeralLowerBound * RepairNumberParsing.apStyleNumeralLowerBound,
               values[nextIndex] > 0,
               values[nextIndex] < RepairNumberParsing.apStyleNumeralLowerBound {
                collect(index: index + 2, groups: groups + [values[index] + values[nextIndex]])
            }
        }

        collect(index: 0, groups: [])
        return alternatives
    }
}
