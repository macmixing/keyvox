import Foundation

/// Finds the package's bundled emoji data, wherever the host copied the bundle's resources.
struct EmojiDataLocator {
    private let bundle: Bundle

    init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    func url(name: String, extension fileExtension: String) throws -> URL {
        if let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "EmojiData"
        ) ?? bundle.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        throw EmojiDataError.missingData("\(name).\(fileExtension)")
    }

    /// The file of a language's data, from `EmojiData/<language>`: the language's own, or, for a
    /// regional variant without its own, the language's it varies, the identifier less its last
    /// subtag, as CLDR's data inherits from it.
    func url(name: String, extension fileExtension: String, language: String) throws -> URL {
        var identifier = Substring(language)
        while true {
            if let url = bundle.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "EmojiData/\(identifier)"
            ) {
                return url
            }
            guard let subtag = identifier.lastIndex(of: "-") else { break }
            identifier = identifier[..<subtag]
        }
        throw EmojiDataError.missingData("\(language)/\(name).\(fileExtension)")
    }
}
