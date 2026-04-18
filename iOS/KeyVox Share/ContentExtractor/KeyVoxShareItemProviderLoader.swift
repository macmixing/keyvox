import Foundation

enum KeyVoxShareItemProviderLoader {
    static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: item)
            }
        }
    }

    static func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    static func loadFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let persistentURL = try makePersistentCopy(of: url)
                    continuation.resume(returning: persistentURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func makePersistentCopy(of fileURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let destinationURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileURL.lastPathComponent, isDirectory: false)

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: fileURL, to: destinationURL)
        KeyVoxShareContentExtractorDiagnostics.log(
            "Copied shared file into persistent temporary URL \(destinationURL.path)."
        )
        return destinationURL
    }
}
