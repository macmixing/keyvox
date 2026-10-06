import Foundation

struct PredictiveArtifactLocator {
    private let bundle: Bundle

    init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    func url(name: String, extension fileExtension: String) throws -> URL {
        if let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Resources"
        ) ?? bundle.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        throw PredictiveKeyboardError.missingArtifact("\(name).\(fileExtension)")
    }

    func directory(named name: String) throws -> URL {
        if let url = bundle.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Resources"
        ) ?? bundle.url(forResource: name, withExtension: nil),
           url.hasDirectoryPath {
            return url
        }
        throw PredictiveKeyboardError.missingArtifact(name)
    }
}
