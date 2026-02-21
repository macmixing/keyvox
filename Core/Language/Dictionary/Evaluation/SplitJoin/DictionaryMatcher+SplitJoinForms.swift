import Foundation

extension DictionaryMatcher {
    func splitJoinForms(from window: [Token]) -> [JoinedObservedForm] {
        guard window.count == 2 else { return [] }

        let first = window[0].normalized
        let second = window[1].normalized

        var forms: [JoinedObservedForm] = []
        var seen = Set<String>()

        let direct = first + second
        if !direct.isEmpty, seen.insert(direct).inserted {
            forms.append(
                JoinedObservedForm(
                    normalized: direct,
                    singularizedSecondToken: false,
                    replacementSuffix: ""
                )
            )
        }

        if second.hasSuffix("'s"), second.count > minimumSplitTokenLength {
            let stem = String(second.dropLast(2))
            if stem.count >= minimumSplitTokenLength {
                let possessiveJoin = first + stem
                if !possessiveJoin.isEmpty, seen.insert(possessiveJoin).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: possessiveJoin,
                            singularizedSecondToken: false,
                            replacementSuffix: "'s"
                        )
                    )
                }
            }
        }

        if second.hasSuffix("s"),
           !second.hasSuffix("'s"),
           !second.hasSuffix("s'"),
           second.count > minimumSplitTokenLength {
            let singularSecond = String(second.dropLast())
            if singularSecond.count >= minimumSplitTokenLength {
                let singularized = first + singularSecond
                if !singularized.isEmpty, seen.insert(singularized).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: singularized,
                            singularizedSecondToken: true,
                            replacementSuffix: "s"
                        )
                    )
                }
            }
        }

        return forms
    }

    func resolvedSplitJoinReplacementSuffix(basePhrase: String, desiredSuffix: String) -> String {
        guard desiredSuffix == "s" else { return desiredSuffix }
        return basePhrase.lowercased().hasSuffix("s") ? "" : "s"
    }
}
