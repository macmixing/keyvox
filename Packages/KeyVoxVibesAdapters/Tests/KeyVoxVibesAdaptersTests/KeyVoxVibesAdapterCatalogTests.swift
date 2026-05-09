import Testing
import KeyVoxVibesAdapters

@Suite("KeyVox Vibes adapter catalog")
struct KeyVoxVibesAdapterCatalogTests {
    @Test("all cataloged adapters resolve bundled resource URLs")
    func allCatalogedAdaptersResolveBundledResourceURLs() throws {
        for adapter in KeyVoxVibesAdapterCatalog.allAdapters {
            let url = try #require(KeyVoxVibesAdapterCatalog.url(for: adapter.kind))
            #expect(url.lastPathComponent == adapter.filename)
        }
    }

    @Test("adapters declare the same compatible base model")
    func adaptersDeclareTheSameCompatibleBaseModel() {
        for adapter in KeyVoxVibesAdapterCatalog.allAdapters {
            #expect(adapter.compatibleBaseModelID == KeyVoxVibesAdapterCatalog.compatibleBaseModelID)
        }
    }
}
