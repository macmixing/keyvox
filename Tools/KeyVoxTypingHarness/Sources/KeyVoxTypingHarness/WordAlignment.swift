/// Lines produced words up with intended words by minimum edit distance over whole
/// words, so a keyboard that splits or joins words is not misaligned for the rest of
/// the sentence.
enum WordAlignment {
    /// For each intended word, the produced word aligned to it, or nil when deleted.
    static func align(intended: [String], produced: [String]) -> [String?] {
        let rows = intended.count
        let columns = produced.count
        var cost = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
        for row in 0...rows { cost[row][0] = row }
        for column in 0...columns { cost[0][column] = column }
        if rows > 0, columns > 0 {
            for row in 1...rows {
                for column in 1...columns {
                    let substitution = cost[row - 1][column - 1]
                        + (intended[row - 1] == produced[column - 1] ? 0 : 1)
                    cost[row][column] = min(
                        substitution,
                        cost[row - 1][column] + 1,
                        cost[row][column - 1] + 1
                    )
                }
            }
        }

        var aligned = [String?](repeating: nil, count: rows)
        var row = rows
        var column = columns
        while row > 0 {
            if column > 0,
               cost[row][column] == cost[row - 1][column - 1]
                + (intended[row - 1] == produced[column - 1] ? 0 : 1) {
                aligned[row - 1] = produced[column - 1]
                row -= 1
                column -= 1
            } else if cost[row][column] == cost[row - 1][column] + 1 {
                row -= 1
            } else {
                column -= 1
            }
        }
        return aligned
    }
}
