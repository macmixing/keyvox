import Foundation
import XCTest
@testable import KeyVoxCore

final class ResourceBundleStorageTests: XCTestCase {
    func testOverrideDoesNotEvaluateDefaultAndCannotChangeAfterAccess() throws {
        let storage = ResourceBundleStorage()
        let bundle = Bundle.main
        try storage.configure(bundle)
        var usedDefault = false
        XCTAssertTrue(storage.resolve { usedDefault = true; return bundle } === bundle)
        XCTAssertFalse(usedDefault)
        XCTAssertThrowsError(try storage.configure(bundle))
    }

    func testDefaultLookupSealsConfiguration() {
        let storage = ResourceBundleStorage()
        let bundle = Bundle.main
        XCTAssertTrue(storage.resolve { bundle } === bundle)
        XCTAssertThrowsError(try storage.configure(bundle))
    }
}
