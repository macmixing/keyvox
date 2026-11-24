// Writes each word's most common lexical class (Noun, Pronoun, Verb, ...) as Apple's
// NaturalLanguage tagger reads it in normalized sentences, one "word<TAB>class" line per word,
// so write_sentence_openers.py can tell the words that refer to people or things. With
// --language, every sentence is tagged in that language; without it, in the language the tagger
// detects, as the bundled English word kinds were. The tagger gives a word joined from several,
// such as a contraction, its first part's class; with --elided-host, a word whose first part is
// an elided article or preposition takes the class of the word that part is joined to instead,
// as French writes an elided article together with its noun.
//
//     xcrun swiftc -O tag_word_kinds.swift -o <scratch>/tag_word_kinds
//     <scratch>/tag_word_kinds [--language <code>] [--elided-host] <data-dir>/word_kinds.tsv <data-dir>/sentences/<source>.txt...

import Foundation
import NaturalLanguage

var arguments = Array(CommandLine.arguments.dropFirst())
var language: NLLanguage?
if arguments.first == "--language", arguments.count >= 2 {
    language = NLLanguage(rawValue: arguments[1])
    arguments.removeFirst(2)
}
let elidedHost = arguments.first == "--elided-host"
if elidedHost {
    arguments.removeFirst()
}
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: tag_word_kinds [--language <code>] [--elided-host] <output.tsv> <sentences.txt>...\n".utf8))
    exit(1)
}
let elidedKinds: Set<NLTag> = [.determiner, .preposition]
let tagger = NLTagger(tagSchemes: [.lexicalClass])

/// The class of the last part of the word at `range`, if its first part is an elided article or
/// preposition.
func hostKind(of range: Range<String.Index>) -> NLTag? {
    var parts: [NLTag] = []
    tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
        if let tag {
            parts.append(tag)
        }
        return true
    }
    guard parts.count > 1, elidedKinds.contains(parts[0]) else { return nil }
    return parts.last
}

var counts: [String: [String: Int]] = [:]
for path in arguments.dropFirst() {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    for line in text.split(separator: "\n") {
        let sentence = String(line)
        tagger.string = sentence
        if let language {
            tagger.setLanguage(language, range: sentence.startIndex..<sentence.endIndex)
        }
        var words: [(Range<String.Index>, NLTag)] = []
        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinContractions]
        ) { tag, range in
            if let tag {
                words.append((range, tag))
            }
            return true
        }
        for (range, tag) in words {
            var kind = tag
            if elidedHost, sentence[range].contains("'"), let host = hostKind(of: range) {
                kind = host
            }
            counts[String(sentence[range]), default: [:]][kind.rawValue, default: 0] += 1
        }
    }
}

let lines = counts.keys.sorted().map { word -> String in
    let kind = counts[word]!.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }!.key
    return "\(word)\t\(kind)"
}
try (lines.joined(separator: "\n") + "\n").write(toFile: arguments[0], atomically: true, encoding: .utf8)
print("\(lines.count) words")
