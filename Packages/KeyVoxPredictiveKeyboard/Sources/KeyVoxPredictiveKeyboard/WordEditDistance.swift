/// Damerau–Levenshtein distance (adjacent swaps count as one edit), giving up early once
/// it exceeds a limit.
enum WordEditDistance {
    /// The distance between `left` and `right`, or `limit + 1` if it is larger than `limit`.
    static func distance(_ left: String, _ right: String, limit: Int) -> Int {
        let a = Array(left)
        let b = Array(right)
        guard abs(a.count - b.count) <= limit else { return limit + 1 }
        guard a.isEmpty == false else { return min(b.count, limit + 1) }
        guard b.isEmpty == false else { return min(a.count, limit + 1) }

        var previousPrevious = Array(0...b.count)
        var previous = previousPrevious
        var current = previous
        for i in 1...a.count {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...b.count {
                var value = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                )
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, previousPrevious[j - 2] + 1)
                }
                current[j] = value
                rowMinimum = min(rowMinimum, value)
            }
            if rowMinimum > limit { return limit + 1 }
            previousPrevious = previous
            previous = current
        }
        return min(previous[b.count], limit + 1)
    }
}
