import Foundation
import Testing
@testable import KeyVox_iOS

struct iOSSharedPathsTests {
    @Test func modelFileURLAppendsExpectedPath() {
        let fileManager = StubContainerFileManager(containerURL: URL(fileURLWithPath: "/tmp/KeyVoxGroup", isDirectory: true))

        let modelURL = iOSSharedPaths.modelFileURL(fileManager: fileManager)
        let modelsDirectoryURL = iOSSharedPaths.modelsDirectoryURL(fileManager: fileManager)
        let coreMLZipURL = iOSSharedPaths.coreMLEncoderZipURL(fileManager: fileManager)
        let coreMLDirectoryURL = iOSSharedPaths.coreMLEncoderDirectoryURL(fileManager: fileManager)
        let manifestURL = iOSSharedPaths.modelInstallManifestURL(fileManager: fileManager)

        #expect(modelURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base.bin")
        #expect(modelsDirectoryURL?.path == "/tmp/KeyVoxGroup/Models")
        #expect(coreMLZipURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base-encoder.mlmodelc.zip")
        #expect(coreMLDirectoryURL?.path == "/tmp/KeyVoxGroup/Models/ggml-base-encoder.mlmodelc")
        #expect(manifestURL?.path == "/tmp/KeyVoxGroup/Models/model-install-manifest.json")
    }

    @Test func dictionaryBaseDirectoryAppendsExpectedPath() {
        let fileManager = StubContainerFileManager(containerURL: URL(fileURLWithPath: "/tmp/KeyVoxGroup", isDirectory: true))

        let dictionaryURL = iOSSharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)

        #expect(dictionaryURL?.path == "/tmp/KeyVoxGroup/KeyVoxCore")
    }

    @Test func nilContainerReturnsNilAndFallbackUsesKeyVoxFallback() {
        let fileManager = StubContainerFileManager(containerURL: nil)

        #expect(iOSSharedPaths.modelFileURL(fileManager: fileManager) == nil)
        #expect(iOSSharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager) == nil)
        #expect(iOSSharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager).lastPathComponent == "KeyVoxFallback")
    }
}

private final class StubContainerFileManager: FileManager, @unchecked Sendable {
    private let stubContainerURL: URL?

    init(containerURL: URL?) {
        self.stubContainerURL = containerURL
        super.init()
    }

    override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
        stubContainerURL
    }
}
