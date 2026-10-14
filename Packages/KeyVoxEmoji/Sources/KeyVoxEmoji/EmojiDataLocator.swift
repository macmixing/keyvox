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
}
