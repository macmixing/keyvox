import Foundation

struct PronunciationLookup: Sendable {
    private let pronunciationsByWord: [String: String]

    init(pronunciationsByWord: [String: String]) {
        self.pronunciationsByWord = pronunciationsByWord
    }

    func pronunciation(for normalizedWord: String) -> String? {
        pronunciationsByWord[normalizedWord]
    }
}

public protocol PronunciationLexiconProviding: AnyObject {
    func pronunciation(for normalizedWord: String) -> String?
    func isCommonWord(_ normalizedWord: String) -> Bool
}

public final class PronunciationLexicon: PronunciationLexiconProviding {
    public static let shared = PronunciationLexicon()

    nonisolated let pronunciationLookup: PronunciationLookup
    private(set) var commonWords: Set<String> = []

    private init(bundle: Bundle = .module) {
        let pronunciationLookup = Self.loadPronunciations(from: bundle)
        self.pronunciationLookup = pronunciationLookup
        loadCommonWords(from: bundle)
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    public func pronunciation(for normalizedWord: String) -> String? {
        pronunciationLookup.pronunciation(for: normalizedWord)
    }

    public func isCommonWord(_ normalizedWord: String) -> Bool {
        commonWords.contains(normalizedWord)
    }

    private static func resourceURL(
        named name: String,
        extension ext: String,
        in bundle: Bundle,
        subdirectory: String
    ) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: ext)
    }

    private static func loadPronunciations(from bundle: Bundle) -> PronunciationLookup {
        guard let url = resourceURL(
            named: "lexicon-v1",
            extension: "tsv",
            in: bundle,
            subdirectory: "Pronunciation"
        ) else {
            #if DEBUG
            print("[PronunciationLexicon] Missing lexicon-v1.tsv resource")
            #endif
            return PronunciationLookup(pronunciationsByWord: [:])
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            var map: [String: String] = [:]

            content.enumerateLines { line, _ in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }

                let pieces = trimmed.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
                guard pieces.count == 2 else { return }

                let rawWord = String(pieces[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let signature = String(pieces[1]).trimmingCharacters(in: .whitespacesAndNewlines)

                guard !rawWord.isEmpty, !signature.isEmpty else { return }
                let normalized = DictionaryTextNormalization.normalizedToken(rawWord)
                guard !normalized.isEmpty else { return }

                map[normalized] = signature
            }

            return PronunciationLookup(pronunciationsByWord: map)
        } catch {
            #if DEBUG
            print("[PronunciationLexicon] Failed to load lexicon-v1.tsv: \(error)")
            #endif
            return PronunciationLookup(pronunciationsByWord: [:])
        }
    }

    private func loadCommonWords(from bundle: Bundle) {
        guard let url = Self.resourceURL(
            named: "common-words-v1",
            extension: "txt",
            in: bundle,
            subdirectory: "Pronunciation"
        ) else {
            #if DEBUG
            print("[PronunciationLexicon] Missing common-words-v1.txt resource")
            #endif
            commonWords = []
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            var loadedWords = Set<String>()

            content.enumerateLines { line, _ in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }

                let normalized = DictionaryTextNormalization.normalizedToken(trimmed)
                guard !normalized.isEmpty else { return }
                loadedWords.insert(normalized)
            }

            commonWords = loadedWords
        } catch {
            #if DEBUG
            print("[PronunciationLexicon] Failed to load common-words-v1.txt: \(error)")
            #endif
            commonWords = []
        }
    }
}
