// Writes each word's most common lexical class (Noun, Pronoun, Verb, ...) as Apple's
// NaturalLanguage tagger reads it in normalized sentences, one "word<TAB>class" line per word,
// so write_sentence_openers.py can tell the words that refer to people or things.
//
//     xcrun swiftc -O tag_word_kinds.swift -o <scratch>/tag_word_kinds
//     <scratch>/tag_word_kinds <data-dir>/word_kinds.tsv <data-dir>/sentences/<source>.txt...

import Foundation
import NaturalLanguage

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: tag_word_kinds <output.tsv> <sentences.txt>...\n".utf8))
    exit(1)
}

let tagger = NLTagger(tagSchemes: [.lexicalClass])
var counts: [String: [String: Int]] = [:]
for path in arguments.dropFirst(2) {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    for line in text.split(separator: "\n") {
        let sentence = String(line)
        tagger.string = sentence
        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinContractions]
        ) { tag, range in
            if let tag {
                counts[String(sentence[range]), default: [:]][tag.rawValue, default: 0] += 1
            }
            return true
        }
    }
}

let lines = counts.keys.sorted().map { word -> String in
    let kind = counts[word]!.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }!.key
    return "\(word)\t\(kind)"
}
try (lines.joined(separator: "\n") + "\n").write(toFile: arguments[1], atomically: true, encoding: .utf8)
print("\(lines.count) words")
