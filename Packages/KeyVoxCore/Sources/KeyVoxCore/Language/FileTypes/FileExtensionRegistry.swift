import Foundation

struct FileExtensionRegistry {
    private struct MediaType: Decodable {
        let extensions: [String]?
    }

    private let extensions: Set<String>

    init(data: Data) throws {
        let types = try JSONDecoder().decode([String: MediaType].self, from: data)
        extensions = Set(types.values.flatMap { $0.extensions ?? [] }.map { $0.lowercased() })
    }

    func recognizes(_ fileExtension: String) -> Bool {
        extensions.contains(fileExtension.lowercased())
    }

    static let bundled: Result<FileExtensionRegistry, Error> = Result {
        guard let url = Bundle.module.url(forResource: "mime-db", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try FileExtensionRegistry(data: Data(contentsOf: url))
    }
}
