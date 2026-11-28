import KeyVoxLinguistics

/// The user's known names, such as contact names, that are everyday words in any of the user's
/// typing languages, or such words written without their apostrophe, so `PredictionComputer`
/// treats such a name as it treats one of its own language's everyday words in every selected
/// language. A name a language spells only with capitals is no everyday word of that language.
/// Each language's dictionary is opened on its own (`TypingLanguageDictionary`) and let go once
/// the names are checked against it, so working this out loads no language's engine and keeps
/// none of their files; a regional variant sharing another language's dictionary is checked once.
public struct EverydayKnownNames: Sendable, Equatable {
    /// No name is an everyday word of another language.
    public static let none = EverydayKnownNames(everydayWords: [], wordsMissingApostrophes: [])

    /// The names' lookup keys (`PersonalVocabulary.key`).
    private let everydayWords: Set<String>
    private let wordsMissingApostrophes: Set<String>

    private init(everydayWords: Set<String>, wordsMissingApostrophes: Set<String>) {
        self.everydayWords = everydayWords
        self.wordsMissingApostrophes = wordsMissingApostrophes
    }

    /// Checks `knownNames`, as a `PersonalVocabulary` holds them, against each of `languages`; with
    /// no names, no dictionary is opened.
    public init(knownNames: [String], languages: [TypingLanguage]) throws {
        guard knownNames.isEmpty == false else {
            self = .none
            return
        }
        var everydayWords: Set<String> = []
        var wordsMissingApostrophes: Set<String> = []
        var checkedDictionaries: Set<String> = []
        for language in languages {
            let dictionaryIdentifier = try language.resources.dataIdentifier(ofDirectory: "dictionary")
            guard checkedDictionaries.insert(dictionaryIdentifier).inserted else { continue }
            let dictionary = try TypingLanguageDictionary(language: language)
            // Built from the same word list as the dictionary, as the engine's are.
            let capitalizedSpellings = try CapitalizedSpellings(languageCode: dictionaryIdentifier)
            for name in knownNames where capitalizedSpellings.spelling(of: name) == nil {
                let key = PersonalVocabulary.key(name)
                if dictionary.hasWord(key) {
                    everydayWords.insert(key)
                } else if MissingApostrophe.isMissing(from: key, isWord: dictionary.hasWord) {
                    wordsMissingApostrophes.insert(key)
                }
            }
        }
        self.init(everydayWords: everydayWords, wordsMissingApostrophes: wordsMissingApostrophes)
    }

    /// Whether `name` is an everyday word of one of the languages.
    func isEverydayWord(_ name: String) -> Bool {
        everydayWords.contains(PersonalVocabulary.key(name))
    }

    /// Whether `name` is a word of one of the languages written without its apostrophe.
    func missesItsApostrophe(_ name: String) -> Bool {
        wordsMissingApostrophes.contains(PersonalVocabulary.key(name))
    }
}
