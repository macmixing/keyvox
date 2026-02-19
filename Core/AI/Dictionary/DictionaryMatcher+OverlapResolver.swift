import Foundation

extension DictionaryMatcher {
    func selectNonOverlapping(
        proposed: [ProposedReplacement],
        rejectedOverlapCounter: inout Int
    ) -> [ProposedReplacement] {
        let sorted = proposed.sorted {
            if $0.score == $1.score {
                let lhsLength = $0.tokenEndExclusive - $0.tokenStart
                let rhsLength = $1.tokenEndExclusive - $1.tokenStart
                if lhsLength == rhsLength {
                    return $0.tokenStart < $1.tokenStart
                }
                return lhsLength > rhsLength
            }
            return $0.score > $1.score
        }

        var selected: [ProposedReplacement] = []
        for candidate in sorted {
            let overlaps = selected.contains { existing in
                candidate.tokenStart < existing.tokenEndExclusive && existing.tokenStart < candidate.tokenEndExclusive
            }

            if overlaps {
                rejectedOverlapCounter += 1
                continue
            }

            selected.append(candidate)
        }

        return selected
    }
}
