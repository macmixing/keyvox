/// Reads the bundled lists written as lines of a key, a tab, and `word:value` pairs separated by
/// spaces, such as `sentence_openers.txt`, without copying their text.
enum ScoredWordLines {
    /// The non-empty lines of `bytes`, without their line breaks.
    static func lines(in bytes: UnsafeRawBufferPointer) -> [Range<Int>] {
        var lines: [Range<Int>] = []
        var start = 0
        for index in bytes.indices where bytes[index] == UInt8(ascii: "\n") {
            if index > start {
                lines.append(start..<index)
            }
            start = index + 1
        }
        return lines
    }

    /// The `word:value` pairs, separated by spaces, in `range`.
    static func pairs(in bytes: UnsafeRawBufferPointer, _ range: Range<Int>) -> [(word: String, value: Float)] {
        bytes[range].split(separator: UInt8(ascii: " ")).compactMap { pair in
            guard let colon = pair.lastIndex(of: UInt8(ascii: ":")),
                  let value = Float(String(decoding: pair[(colon + 1)...], as: UTF8.self)) else { return nil }
            return (String(decoding: pair[..<colon], as: UTF8.self), value)
        }
    }
}
