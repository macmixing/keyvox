import Foundation
import KeyVoxVibesAdapters

/// Finds the installed Vibes rewrite model and its adapters without owning their installation.
struct InstalledLocalRewriteModelLocator {
    let fileManager: FileManager
    let descriptor: LocalRewriteModelDescriptor
    let rootURL: URL?

    init(
        fileManager: FileManager = .default,
        descriptor: LocalRewriteModelDescriptor = LocalRewriteModelCatalog.descriptor,
        rootURL: URL? = SharedPaths.localRewriteModelDirectoryURL(fileManager: .default)
    ) {
        self.fileManager = fileManager
        self.descriptor = descriptor
        self.rootURL = rootURL
    }

    var artifactURL: URL? {
        rootURL?.appendingPathComponent(descriptor.artifact.filename, isDirectory: false)
    }

    var manifestURL: URL? {
        rootURL?.appendingPathComponent(LocalRewriteModelCatalog.manifestFilename, isDirectory: false)
    }

    func isModelReady() -> Bool {
        guard let manifestURL,
              let artifactURL,
              fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: artifactURL.path),
              let manifest = try? readManifest(from: manifestURL) else {
            return false
        }

        return manifest.modelID == descriptor.id
            && manifest.artifactFilename == descriptor.artifact.filename
            && manifest.expectedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
            && manifest.installedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
    }

    func installedModelURL() -> URL? {
        guard isModelReady() else { return nil }
        return artifactURL
    }

    func adapterURL(for kind: KeyVoxVibesAdapterKind) -> URL? {
        if let bundledAdapterURL = KeyVoxVibesAdapterCatalog.url(for: kind) {
            return bundledAdapterURL
        }

        guard isModelReady(),
              let adapterURL = rootURL?.appendingPathComponent(
                  KeyVoxVibesAdapterCatalog.descriptor(for: kind).filename,
                  isDirectory: false
              ) else {
            return nil
        }

        return fileManager.fileExists(atPath: adapterURL.path) ? adapterURL : nil
    }

    func readManifest(from url: URL) throws -> LocalRewriteModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LocalRewriteModelInstallManifest.self, from: data)
    }
}
