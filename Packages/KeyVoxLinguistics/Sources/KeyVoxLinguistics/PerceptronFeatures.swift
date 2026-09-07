// Feature schema adapted from NLTK 3.9.1's MIT-licensed nltk/tag/perceptron.py.
// Copyright 2013 Matthew Honnibal; modifications Copyright 2015 The NLTK Project.
// See THIRD_PARTY_NOTICES.md for the complete MIT notice and source attribution.
import Foundation

enum PerceptronFeatures {
    static let start = ["-START-", "-START2-"]
    static let end = ["-END-", "-END2-"]

    static func normalize(_ word: String) -> String {
        let scalars = Array(word.unicodeScalars)
        if word.contains("-"), scalars.first != "-" { return "!HYPHEN" }
        func isDigit(_ scalar: Unicode.Scalar) -> Bool {
            scalar.properties.numericType == .decimal || scalar.properties.numericType == .digit
        }
        if scalars.count == 4, scalars.allSatisfy(isDigit) { return "!YEAR" }
        if let first = scalars.first, isDigit(first) { return "!DIGITS" }
        return word.lowercased()
    }

    private static func suffix(_ word: String) -> String {
        String(String.UnicodeScalarView(word.unicodeScalars.suffix(3)))
    }

    static func values(index: Int, word: String, context: [String], previous: String, previous2: String) -> [String] {
        let i = index + start.count
        return [
            "bias", "i suffix " + suffix(word),
            "i pref1 " + String(String.UnicodeScalarView(word.unicodeScalars.prefix(1))),
            "i-1 tag " + previous, "i-2 tag " + previous2,
            "i tag+i-2 tag " + previous + " " + previous2,
            "i word " + context[i], "i-1 tag+i word " + previous + " " + context[i],
            "i-1 word " + context[i - 1], "i-1 suffix " + suffix(context[i - 1]),
            "i-2 word " + context[i - 2], "i+1 word " + context[i + 1],
            "i+1 suffix " + suffix(context[i + 1]), "i+2 word " + context[i + 2],
        ]
    }
}
