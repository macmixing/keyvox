import Foundation

enum PerceptronModelLoader {
    struct Descriptor: Decodable {
        let schema: String
        let tagSet: String
        let languages: [String]
        let weights: String
        let classes: String
        let tagDictionary: String
    }

    static func load(directory: URL) throws -> (Descriptor, PerceptronModel) {
        let decoder = JSONDecoder()
        let descriptor = try decoder.decode(Descriptor.self, from: Data(contentsOf: directory.appendingPathComponent("model.json")))
        guard descriptor.schema == "nltk-perceptron-v1", descriptor.tagSet == "penn-treebank",
              !descriptor.languages.isEmpty,
              descriptor.languages.allSatisfy({ ModelLanguageIdentifier.base($0) != nil }) else {
            throw PerceptronModel.Failure.invalidModel
        }
        func data(_ filename: String) throws -> Data {
            guard !filename.isEmpty, filename != ".", filename != "..",
                  URL(fileURLWithPath: filename).lastPathComponent == filename else {
                throw PerceptronModel.Failure.invalidModel
            }
            return try Data(contentsOf: directory.appendingPathComponent(filename))
        }
        let model = try PerceptronModel(
            weights: decoder.decode([String: [String: Double]].self, from: data(descriptor.weights)),
            knownTags: decoder.decode([String: String].self, from: data(descriptor.tagDictionary)),
            classes: decoder.decode([String].self, from: data(descriptor.classes))
        )
        return (descriptor, model)
    }
}
