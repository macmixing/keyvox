import Foundation

/// Loads evaluation sentences from plain-text files (one passage per line) or
/// chat-style JSONL files (the final assistant message of each record).
enum CorpusLoader {
    static func sentences(from paths: [String]) throws -> [String] {
        var observed: Set<String> = []
        var sentences: [String] = []
        for path in paths {
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
                throw HarnessError.unreadableCorpus(path)
            }
            let passages = path.hasSuffix(".jsonl")
                ? assistantMessages(fromJSONLines: contents)
                : contents.components(separatedBy: .newlines)
            for passage in passages {
                for sentence in splitIntoSentences(passage)
                where observed.insert(sentence.lowercased()).inserted {
                    sentences.append(sentence)
                }
            }
        }
        return sentences
    }

    private static func assistantMessages(fromJSONLines contents: String) -> [String] {
        contents.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8),
                  let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = record["messages"] as? [[String: Any]] else {
                return nil
            }
            return messages.last { $0["role"] as? String == "assistant" }?["content"] as? String
        }
    }

    private static func splitIntoSentences(_ passage: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in passage {
            if character.isNewline {
                appendTrimmed(current, to: &sentences)
                current = ""
                continue
            }
            current.append(character)
            if ".!?".contains(character) {
                appendTrimmed(current, to: &sentences)
                current = ""
            }
        }
        appendTrimmed(current, to: &sentences)
        return sentences
    }

    private static func appendTrimmed(_ value: String, to sentences: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty == false { sentences.append(trimmed) }
    }
}
