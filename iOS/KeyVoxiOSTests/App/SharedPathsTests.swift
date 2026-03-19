import Foundation
import Testing
@testable import KeyVox_iOS

struct SharedPathsTests {
    @Test func modelFileURLAppendsExpectedPath() {
        let fileManager = StubContainerFileManager(containerURL: URL(fileURLWithPath: "/tmp/KeyVoxGroup", isDirectory: true))

        let modelURL = SharedPaths.modelFileURL(fileManager: fileManager)
        let modelsDirectoryURL = SharedPaths.modelsDirectoryURL(fileManager: fileManager)
        let coreMLZipURL = SharedPaths.coreMLEncoderZipURL(fileManager: fileManager)
        let coreMLDirectoryURL = SharedPaths.coreMLEncoderDirectoryURL(fileManager: fileManager)
        let manifestURL = SharedPaths.modelInstallManifestURL(fileManager: fileManager)

        #expect(modelURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base.bin")
        #expect(modelsDirectoryURL?.path == "/tmp/KeyVoxGroup/Models")
        #expect(coreMLZipURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base-encoder.mlmodelc.zip")
        #expect(coreMLDirectoryURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base-encoder.mlmodelc")
        #expect(manifestURL?.path == "/tmp/KeyVoxGroup/Models/model-install-manifest.json")
    }

    @Test func dictionaryBaseDirectoryAppendsExpectedPath() {
        let fileManager = StubContainerFileManager(containerURL: URL(fileURLWithPath: "/tmp/KeyVoxGroup", isDirectory: true))

        let dictionaryURL = SharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)

        #expect(dictionaryURL?.path == "/tmp/KeyVoxGroup/KeyVoxCore")
    }

    @Test func nilContainerReturnsNilAndFallbackUsesKeyVoxFallback() {
        let fileManager = StubContainerFileManager(containerURL: nil)

        #expect(SharedPaths.modelFileURL(fileManager: fileManager) == nil)
        #expect(SharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager) == nil)
        #expect(SharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager).lastPathComponent == "KeyVoxFallback")
    }
}

private final class StubContainerFileManager: FileManager {
    private let stubContainerURL: URL?

    init(containerURL: URL?) {
        self.stubContainerURL = containerURL
        super.init()
    }

    override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
        stubContainerURL
    }
}
