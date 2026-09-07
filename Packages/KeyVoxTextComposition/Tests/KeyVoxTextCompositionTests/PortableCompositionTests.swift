import CompositionVerification
import XCTest

final class PortableCompositionTests: XCTestCase {
    func testPortableComposition() throws {
        try CompositionVerification.verify()
    }
}
