import Foundation

/// Immutable inference-only representation of the published perceptron schema.
struct PerceptronModel: Sendable {
    enum Failure: Error { case invalidModel }
    let weights: [String: [String: Double]]
    let knownTags: [String: String]
    let classes: [String]

    init(weights: [String: [String: Double]], knownTags: [String: String], classes: [String]) throws {
        let labels = Set(classes)
        guard !labels.isEmpty, labels.count == classes.count,
              knownTags.values.allSatisfy(labels.contains),
              weights.values.allSatisfy({ row in
                  row.allSatisfy { labels.contains($0.key) && $0.value.isFinite }
              }) else { throw Failure.invalidModel }
        self.weights = weights
        self.knownTags = knownTags
        self.classes = classes.sorted()
    }

    func tags(for words: [String]) -> [String]? {
        let context = PerceptronFeatures.start + words.map(PerceptronFeatures.normalize) + PerceptronFeatures.end
        var previous = PerceptronFeatures.start[0]
        var previous2 = PerceptronFeatures.start[1]
        var result: [String] = []
        for (index, word) in words.enumerated() {
            let tag: String
            if let known = structurallyKnownTag(for: word, at: index) {
                tag = known
            } else {
                var scores: [String: Double] = [:]
                for feature in PerceptronFeatures.values(index: index, word: word, context: context,
                                                         previous: previous, previous2: previous2) {
                    for (label, weight) in weights[feature] ?? [:] {
                        scores[label, default: 0] += weight
                    }
                }
                guard scores.values.allSatisfy(\.isFinite) else { return nil }
                // Published predictor breaks score ties by greatest label.
                tag = classes.max { lhs, rhs in
                    let left = scores[lhs, default: 0], right = scores[rhs, default: 0]
                    return left == right ? lhs < rhs : left < right
                }!
            }
            result.append(tag)
            previous2 = previous
            previous = tag
        }
        return result
    }

    func knownTag(for word: String) -> String? {
        knownTags[word]
    }

    private func structurallyKnownTag(for word: String, at index: Int) -> String? {
        if let known = knownTags[word] { return known }

        let leadingWordScalars = word.unicodeScalars.prefix {
            CharacterSet.alphanumerics.contains($0)
        }
        if leadingWordScalars.count < word.unicodeScalars.count {
            let leadingWord = String(String.UnicodeScalarView(leadingWordScalars))
            if let known = knownTags[leadingWord] ?? knownTags[leadingWord.lowercased()] {
                return known
            }
        }

        guard index == 0,
              word.first?.isUppercase == true,
              let known = knownTags[word.lowercased()],
              known.hasPrefix("VB") else {
            return nil
        }
        return known
    }
}
