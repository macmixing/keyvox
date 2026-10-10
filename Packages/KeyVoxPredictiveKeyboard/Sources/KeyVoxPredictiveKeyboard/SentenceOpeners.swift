import Foundation

/// The words the suggestion bar offers where a sentence begins: every opener scored by its log
/// likelihood after the previous sentence's ending, plus a boost for that sentence's first word
/// and one for each word in it under that ending, the best three first. The model is written by
/// Tools/KeyVoxLanguageModel/write_sentence_openers.py, which documents the file's lines.
public struct SentenceOpeners: Sendable {
    private static let noEnding = "*"

    /// The openers, in the order of every ending's scores.
    private let openers: [String]
    /// Each ending's opener scores by the ending's name, with `noEnding` where no earlier
    /// sentence ended.
    private let endingScores: [String: [Float]]
    /// Each boost line's 64-bit FNV-1a key hash, sorted. The boosts for the key at `i` are the
    /// openers `boostOpeners[boostStarts[i]..<boostStarts[i + 1]]` with `boostValues` alike:
    /// flat arrays, so the model costs a few bytes per boost in memory.
    private let boostHashes: [UInt64]
    private let boostStarts: [Int]
    private let boostOpeners: [UInt16]
    private let boostValues: [Float]

    /// Reads the file, mapped rather than copied, without keeping its text.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        var openers: [String] = []
        var openerIndices: [String: UInt16] = [:]
        var endingScores: [String: [Float]] = [:]
        var boostLines: [(hash: UInt64, values: Range<Int>)] = []
        var boostHashes: [UInt64] = []
        var boostStarts: [Int] = []
        var boostOpeners: [UInt16] = []
        var boostValues: [Float] = []

        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let endingPrefix = Array("ending ".utf8)
            for line in ScoredWordLines.lines(in: bytes) {
                guard let tab = bytes[line].firstIndex(of: UInt8(ascii: "\t")) else { continue }
                let values = (tab + 1)..<line.upperBound
                guard bytes[line].starts(with: endingPrefix) else {
                    boostLines.append((Self.hash(bytes[line.lowerBound..<tab]), values))
                    continue
                }
                let name = String(decoding: bytes[(line.lowerBound + endingPrefix.count)..<tab], as: UTF8.self)
                let pairs = ScoredWordLines.pairs(in: bytes, values)
                if openers.isEmpty {
                    openers = pairs.map(\.word)
                    for (index, opener) in openers.enumerated() {
                        openerIndices[opener] = UInt16(index)
                    }
                }
                var scores = [Float](repeating: -.infinity, count: openers.count)
                for pair in pairs {
                    if let index = openerIndices[pair.word] {
                        scores[Int(index)] = pair.value
                    }
                }
                endingScores[name] = scores
            }

            boostLines.sort { $0.hash < $1.hash }
            for line in boostLines {
                boostHashes.append(line.hash)
                boostStarts.append(boostOpeners.count)
                for pair in ScoredWordLines.pairs(in: bytes, line.values) {
                    if let index = openerIndices[pair.word] {
                        boostOpeners.append(index)
                        boostValues.append(pair.value)
                    }
                }
            }
            boostStarts.append(boostOpeners.count)
        }
        self.openers = openers
        self.endingScores = endingScores
        self.boostHashes = boostHashes
        self.boostStarts = boostStarts
        self.boostOpeners = boostOpeners
        self.boostValues = boostValues
    }

    /// The best openers, most likely first, after `ending`, or the general openers when no
    /// earlier sentence ended or the last one ended at a bare line break.
    public func words(after ending: SentenceEnding?) -> [String] {
        guard var scores = endingScores[Self.noEnding] else { return [] }
        if let ending, let endingScores = endingScores[ending.mark.rawValue] {
            scores = endingScores
            addBoosts(for: "first \(ending.mark.rawValue) \(ending.firstWord)", to: &scores)
            for word in Set(ending.words) {
                addBoosts(for: "word \(ending.mark.rawValue) \(word)", to: &scores)
            }
        }
        let best = scores.indices.sorted { left, right in
            scores[left] != scores[right] ? scores[left] > scores[right] : openers[left] < openers[right]
        }
        return best.prefix(3).map { openers[$0] }
    }

    private func addBoosts(for key: String, to scores: inout [Float]) {
        let hash = Self.hash(key.utf8)
        var low = 0
        var high = boostHashes.count
        while low < high {
            let middle = (low + high) / 2
            if boostHashes[middle] < hash {
                low = middle + 1
            } else {
                high = middle
            }
        }
        guard low < boostHashes.count, boostHashes[low] == hash else { return }
        for index in boostStarts[low]..<boostStarts[low + 1] {
            scores[Int(boostOpeners[index])] += boostValues[index]
        }
    }

    private static func hash<Bytes: Sequence>(_ bytes: Bytes) -> UInt64 where Bytes.Element == UInt8 {
        bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
