import Foundation

struct AccentSuggestionOverlay: Sendable {
    private struct Entry: Sendable {
        let word: String
        let probability: UInt8
    }

    private let entriesByFoldedWord: [String: [Entry]]

    init(data: Data) throws {
        guard data.count >= 12,
              String(decoding: data.prefix(8), as: UTF8.self) == "KVAC0001" else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }

        var offset = 8
        let count = try data.readUInt32(at: &offset)
        var entries: [String: [Entry]] = [:]
        for _ in 0..<count {
            let keyLength = Int(try data.readUInt8(at: &offset))
            let wordLength = Int(try data.readUInt8(at: &offset))
            let probability = try data.readUInt8(at: &offset)
            let key = try data.readString(length: keyLength, at: &offset)
            let word = try data.readString(length: wordLength, at: &offset)
            entries[key, default: []].append(Entry(word: word, probability: probability))
        }
        guard offset == data.count else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }
        entriesByFoldedWord = entries.mapValues {
            $0.sorted { left, right in
                if left.probability != right.probability {
                    return left.probability > right.probability
                }
                return left.word < right.word
            }
        }
    }

    func suggestions(for foldedWord: String) -> [String] {
        entriesByFoldedWord[foldedWord.lowercased()]?.map(\.word) ?? []
    }
}

private extension Data {
    func readUInt8(at offset: inout Int) throws -> UInt8 {
        guard indices.contains(offset) else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }
        defer { offset += 1 }
        return self[offset]
    }

    func readUInt32(at offset: inout Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }
        let value = withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        return UInt32(littleEndian: value)
    }

    func readString(length: Int, at offset: inout Int) throws -> String {
        guard length >= 0, offset >= 0, offset + length <= count else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }
        let data = self[offset..<(offset + length)]
        offset += length
        guard let value = String(data: data, encoding: .utf8) else {
            throw PredictiveKeyboardError.invalidAccentOverlay
        }
        return value
    }
}
