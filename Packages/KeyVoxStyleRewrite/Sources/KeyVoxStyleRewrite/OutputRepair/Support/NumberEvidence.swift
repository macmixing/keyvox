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

        var components: [Component]?
        for token in tokens {
            if RepairNumberParsing.isSpellOutDecimalSeparator(token) {
                components = (components ?? []) + [.separator]
            } else if let value = RepairNumberParsing.numericValue(for: token) {
                components = (components ?? []) + [.value(value)]
            } else {
                components = nil
                break
            }
        }

        if let components {
            if components.contains(.separator) {
                return components
            }
            if let digitSequence = digitSequenceComponents(in: tokens) {
                return digitSequence
            }
            return components
        }

        if let digitSequence = digitSequenceComponents(in: tokens) {
            return digitSequence
        }

        return nil
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
        let leftDecimalText = decimalReplacementText(evidence: leftEvidence, tokens: leftRun)
        let rightDecimalText = decimalReplacementText(evidence: rightEvidence, tokens: rightRun)
        if let leftDecimalText,
           let rightDecimalText,
           leftDecimalText != rightDecimalText {
            return false
        }

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
        if let decimalText = decimalReplacementText(evidence: evidence, tokens: tokens) {
            return decimalText
        }

        if tokens.count > 1,
           evidence.count == 1,
           case let .value(value) = evidence[0] {
            return String(value)
        }

        return String(sourceText[sourceRange])
    }

    static func decimalReplacementText(evidence: [Component]) -> String? {
        decimalReplacementText(evidence: evidence, tokens: nil)
    }

    static func decimalReplacementText(evidence: [Component], tokens: [RepairWordToken]?) -> String? {
        guard let separatorIndex = evidence.firstIndex(of: .separator),
              separatorIndex == 1,
              evidence[(separatorIndex + 1)...].contains(.separator) == false else {
            return nil
        }

        guard case let .value(major) = evidence[0] else {
            return nil
        }

        var minorParts: [String] = []
        for index in evidence.indices[(separatorIndex + 1)...] {
            let component = evidence[index]
            guard case let .value(value) = component,
                  (0..<100).contains(value) else {
                return nil
            }
            if let token = tokens?[safe: index],
               token.text.allSatisfy(\.isNumber) {
                minorParts.append(token.text)
            } else {
                minorParts.append(String(value))
            }
        }

        guard !minorParts.isEmpty else {
            return nil
        }

        return "\(major).\(minorParts.joined())"
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

    private static func digitSequenceComponents(in tokens: [RepairWordToken]) -> [Component]? {
        guard tokens.count > 1,
              let value = RepairNumberParsing.parsedDigitSequence(from: tokens.map(\.text)) else {
            return nil
        }
        return [.value(value)]
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
