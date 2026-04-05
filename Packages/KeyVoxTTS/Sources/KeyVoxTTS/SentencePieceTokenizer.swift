import Foundation

struct SentencePieceTokenizer: Sendable {
    private static let wordBoundaryMarker: Character = "\u{2581}"

    private let pieces: [SentencePieceModelParser.Piece]
    private let tokenIDsByPiece: [String: Int]
    private let longestPieceScalarLength: Int

    init(modelData: Data) throws {
        let parsedPieces = try SentencePieceModelParser.parse(modelData)
        pieces = parsedPieces

        var lookup: [String: Int] = [:]
        var maxLength = 0
        for (index, piece) in parsedPieces.enumerated() {
            lookup[piece.token] = index
            maxLength = max(maxLength, piece.token.unicodeScalars.count)
        }
        tokenIDsByPiece = lookup
        longestPieceScalarLength = maxLength
    }

    func encode(_ text: String) -> [Int] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalized = String(Self.wordBoundaryMarker)
            + trimmed.replacingOccurrences(of: " ", with: String(Self.wordBoundaryMarker))
        return bestTokenization(for: normalized)
    }

    private func bestTokenization(for text: String) -> [Int] {
        let scalars = Array(text.unicodeScalars)
        guard !scalars.isEmpty else { return [] }

        let unreachable: Float = -.infinity
        var bestScore = Array(repeating: unreachable, count: scalars.count + 1)
        var bestBackpointer = Array(repeating: (tokenID: 0, startIndex: 0), count: scalars.count + 1)
        bestScore[0] = 0

        for startIndex in 0..<scalars.count {
            guard bestScore[startIndex] > unreachable else { continue }

            let maxLength = min(longestPieceScalarLength, scalars.count - startIndex)
            for candidateLength in 1...maxLength {
                let endIndex = startIndex + candidateLength
                let candidate = String(String.UnicodeScalarView(scalars[startIndex..<endIndex]))
                guard let tokenID = tokenIDsByPiece[candidate] else { continue }

                let score = bestScore[startIndex] + pieces[tokenID].score
                if score > bestScore[endIndex] {
                    bestScore[endIndex] = score
                    bestBackpointer[endIndex] = (tokenID, startIndex)
                }
            }
        }

        guard bestScore[scalars.count] > unreachable else {
            return fallbackCharacterEncoding(scalars)
        }

        var tokenIDs: [Int] = []
        var cursor = scalars.count
        while cursor > 0 {
            let state = bestBackpointer[cursor]
            tokenIDs.append(state.tokenID)
            cursor = state.startIndex
        }
        return tokenIDs.reversed()
    }

    private func fallbackCharacterEncoding(_ scalars: [UnicodeScalar]) -> [Int] {
        scalars.compactMap { tokenIDsByPiece[String($0)] }
    }
}
