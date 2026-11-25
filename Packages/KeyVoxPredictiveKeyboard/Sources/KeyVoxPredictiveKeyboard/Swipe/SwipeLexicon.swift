import Foundation

/// The words a swipe can decode to: a typing language's swipe lexicon file
/// (`SwipeLexiconFormat`), memory-mapped, so its pages load only as the search reaches them.
final class SwipeLexicon: @unchecked Sendable {
    /// The lexicon's tables, valid only inside `withTables`.
    struct Tables {
        let nodeCount: Int
        let childStart: UnsafePointer<UInt32>
        let childNode: UnsafePointer<UInt32>
        let formStart: UnsafePointer<UInt32>
        let formSpellingStart: UnsafePointer<UInt32>
        let spellingOffset: UnsafePointer<UInt32>
        let nodeKey: UnsafePointer<UInt8>
        let nodeDepth: UnsafePointer<UInt8>
        let formFrequency: UnsafePointer<UInt8>
        let formPathLength: UnsafePointer<UInt8>
        let spellingFrequency: UnsafePointer<UInt8>
        let spellingBytes: UnsafePointer<UInt8>

        /// The spellings of `form`, likeliest first, with their dictionary probabilities.
        func spellings(of form: Int) -> [(spelling: String, probability: Int)] {
            (Int(formSpellingStart[form])..<Int(formSpellingStart[form + 1])).map { spelling in
                let start = Int(spellingOffset[spelling])
                let bytes = UnsafeBufferPointer(
                    start: spellingBytes + start,
                    count: Int(spellingOffset[spelling + 1]) - start
                )
                return (String(decoding: bytes, as: UTF8.self), Int(spellingFrequency[spelling]))
            }
        }
    }

    private struct Layout {
        var nodeCount = 0
        var formCount = 0
        var spellingCount = 0
        var spellingByteCount = 0
        var offsets: [Int] = []
    }

    /// The model keys the lexicon's key paths are on.
    let letters: String
    let keepsDoubleLetters: Bool
    private let data: Data
    private let layout: Layout

    convenience init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .alwaysMapped), name: url.lastPathComponent)
    }

    /// A lexicon held in memory, such as the user's own words.
    init(data: Data, name: String = SwipeLexiconFormat.fileName) throws {
        let invalid = PredictiveKeyboardError.invalidSwipeModel(name)
        var reader = Reader(data: data)
        guard try reader.bytes(SwipeLexiconFormat.magic.count) == SwipeLexiconFormat.magic,
              try reader.uint32() == SwipeLexiconFormat.version else {
            throw invalid
        }
        let letterCount = Int(try reader.uint32())
        guard let letters = String(bytes: try reader.bytes(letterCount), encoding: .utf8) else {
            throw invalid
        }
        _ = try reader.bytes((4 - letterCount % 4) % 4)
        let keepsDoubleLetters = try reader.uint32() == 1
        var layout = Layout()
        layout.nodeCount = Int(try reader.uint32())
        layout.formCount = Int(try reader.uint32())
        layout.spellingCount = Int(try reader.uint32())
        layout.spellingByteCount = Int(try reader.uint32())
        guard layout.nodeCount > 0 else { throw invalid }
        let wordTables = [
            layout.nodeCount + 1,
            layout.nodeCount - 1,
            layout.nodeCount + 1,
            layout.formCount + 1,
            layout.spellingCount + 1,
        ]
        let byteTables = [
            layout.nodeCount,
            layout.nodeCount,
            layout.formCount,
            layout.formCount,
            layout.spellingCount,
            layout.spellingByteCount,
        ]
        var offset = reader.offset
        for count in wordTables {
            layout.offsets.append(offset)
            offset += count * MemoryLayout<UInt32>.size
        }
        for count in byteTables {
            layout.offsets.append(offset)
            offset += count
        }
        guard offset == data.count, reader.offset % MemoryLayout<UInt32>.alignment == 0 else { throw invalid }
        self.letters = letters
        self.keepsDoubleLetters = keepsDoubleLetters
        self.data = data
        self.layout = layout
    }

    func withTables<Result>(_ body: (Tables) throws -> Result) rethrows -> Result {
        try data.withUnsafeBytes { raw in
            let base = raw.baseAddress!
            func words(_ table: Int) -> UnsafePointer<UInt32> {
                (base + layout.offsets[table]).assumingMemoryBound(to: UInt32.self)
            }
            func bytes(_ table: Int) -> UnsafePointer<UInt8> {
                (base + layout.offsets[table]).assumingMemoryBound(to: UInt8.self)
            }
            return try body(Tables(
                nodeCount: layout.nodeCount,
                childStart: words(0),
                childNode: words(1),
                formStart: words(2),
                formSpellingStart: words(3),
                spellingOffset: words(4),
                nodeKey: bytes(5),
                nodeDepth: bytes(6),
                formFrequency: bytes(7),
                formPathLength: bytes(8),
                spellingFrequency: bytes(9),
                spellingBytes: bytes(10)
            ))
        }
    }

    /// Reads the file's header in order.
    private struct Reader {
        let data: Data
        var offset = 0

        mutating func bytes(_ count: Int) throws -> [UInt8] {
            guard count >= 0, offset + count <= data.count else {
                throw PredictiveKeyboardError.invalidSwipeModel(SwipeLexiconFormat.fileName)
            }
            defer { offset += count }
            return [UInt8](data[data.startIndex + offset..<data.startIndex + offset + count])
        }

        mutating func uint32() throws -> UInt32 {
            let bytes = try bytes(4)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
        }
    }
}
