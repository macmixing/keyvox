import Foundation

internal struct ParakeetVocabulary {
    internal enum TokenKind: Equatable {
        case text(String)
        case language(String)
        case control(String)
    }

    private static let reservedControlTokens: Set<String> = [
        "nospeech",
        "endoftext",
        "startoftranscript",
        "pnc",
        "nopnc",
        "startofcontext",
        "itn",
        "noitn",
        "timestamp",
        "notimestamp",
        "diarize",
        "nodiarize",
        "spkchange",
        "audioseparator",
        "unklang",
        "predict_lang",
        "nopredict_lang"
    ]

    private let tokensByID: [Int32: String]

    init(modelDirectoryURL: URL) throws {
        let fileManager = FileManager.default
        let canonicalURL = modelDirectoryURL.appendingPathComponent("parakeet_vocab.json", isDirectory: false)
        let fallbackURL = modelDirectoryURL.appendingPathComponent("parakeet_v3_vocab.json", isDirectory: false)
        let vocabularyURL = fileManager.fileExists(atPath: canonicalURL.path) ? canonicalURL : fallbackURL
        let data = try Data(contentsOf: vocabularyURL)
        let rawTokens = try JSONDecoder().decode([String: String].self, from: data)

        var tokensByID: [Int32: String] = [:]
        tokensByID.reserveCapacity(rawTokens.count)

        for (rawID, token) in rawTokens {
            guard let tokenID = Int32(rawID) else { continue }
            tokensByID[tokenID] = token
        }

        self.tokensByID = tokensByID

#if DEBUG
        print("[ParakeetCoreML] loaded_vocab=\(vocabularyURL.lastPathComponent)")
#endif
    }

    var tokenCount: Int32 {
        Int32(tokensByID.count)
    }

    func token(for tokenID: Int32) -> String? {
        tokensByID[tokenID]
    }

    func kind(for tokenID: Int32) -> TokenKind? {
        guard let token = token(for: tokenID) else { return nil }

        guard token.hasPrefix("<|"), token.hasSuffix("|>") else {
            return .text(token)
        }

        let content = String(token.dropFirst(2).dropLast(2))
        if Self.reservedControlTokens.contains(content) {
            return .control(content)
        }

        if content.range(of: #"^[A-Za-z]{2,3}([_-][A-Za-z0-9]+)?$"#, options: .regularExpression) != nil {
            return .language(content.replacingOccurrences(of: "_", with: "-"))
        }

        return .control(content)
    }

    func languageName(for languageCode: String) -> String? {
        Locale.current.localizedString(forIdentifier: languageCode)
            ?? Locale.current.localizedString(forLanguageCode: languageCode)
    }

    func decodedText(from tokenIDs: [Int32]) -> String {
        let pieces = tokenIDs.compactMap { tokenID -> String? in
            guard case let .text(token)? = kind(for: tokenID) else { return nil }
            return token
        }

        let joined = pieces.joined()
            .replacingOccurrences(of: "▁", with: " ")
            .replacingOccurrences(of: "Ġ", with: " ")

        return joined
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
