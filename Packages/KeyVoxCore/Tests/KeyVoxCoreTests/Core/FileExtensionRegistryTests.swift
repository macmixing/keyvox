import Foundation
import XCTest
@testable import KeyVoxCore

final class FileExtensionRegistryTests: XCTestCase {
    func testRegistryUsesDeclaredExtensionsAndInvariantCase() throws {
        let declared = UUID().uuidString.lowercased()
        let unknown = UUID().uuidString.lowercased()
        let data = try JSONSerialization.data(withJSONObject: [
            UUID().uuidString: ["extensions": [declared]],
            UUID().uuidString: [:],
        ])
        let registry = try FileExtensionRegistry(data: data)
        XCTAssertTrue(registry.recognizes(declared))
        XCTAssertTrue(registry.recognizes(declared.uppercased()))
        XCTAssertFalse(registry.recognizes(unknown))
        XCTAssertFalse(registry.recognizes("." + declared))
    }

    func testBundledRegistryIsAvailableAndUnknownRemainsUnknown() throws {
        _ = try FileExtensionRegistry.bundled.get()
        XCTAssertEqual(FileExtensionRecognition.portableStatus(for: UUID().uuidString), .unknown)
    }

    func testMalformedRegistryFailsInsteadOfInventingTypes() {
        XCTAssertThrowsError(try FileExtensionRegistry(data: Data()))
    }
}
