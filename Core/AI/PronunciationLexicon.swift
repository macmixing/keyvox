import Foundation

@MainActor
final class PronunciationLexicon {
    static let shared = PronunciationLexicon()

    private(set) var pronunciationsByWord: [String: String] = [:]
    private(set) var commonWords: Set<String> = []

    private init(bundle: Bundle = .main) {
        loadPronunciations(from: bundle)
        loadCommonWords(from: bundle)
    }

    func pronunciation(for normalizedWord: String) -> String? {
        pronunciationsByWord[normalizedWord]
    }

    func isCommonWord(_ normalizedWord: String) -> Bool {
        commonWords.contains(normalizedWord)
    }

    private func loadPronunciations(from bundle: Bundle) {
        guard let url = bundle.url(forResource: "lexicon-v1", withExtension: "tsv", subdirectory: "Pronunciation") else {
            #if DEBUG
            print("[PronunciationLexicon] Missing lexicon-v1.tsv resource")
            #endif
            pronunciationsByWord = [:]
            return
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
                let normalized = TextNormalization.normalizedToken(rawWord)
                guard !normalized.isEmpty else { return }

                map[normalized] = signature
            }

            pronunciationsByWord = map
        } catch {
            #if DEBUG
            print("[PronunciationLexicon] Failed to load lexicon-v1.tsv: \(error)")
            #endif
            pronunciationsByWord = [:]
        }
    }

    private func loadCommonWords(from bundle: Bundle) {
        guard let url = bundle.url(forResource: "common-words-v1", withExtension: "txt", subdirectory: "Pronunciation") else {
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

                let normalized = TextNormalization.normalizedToken(trimmed)
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
