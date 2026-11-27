import Foundation
import Testing
@testable import KeyVox_iOS

/// A host can hand over no document identifier although UIKit declares one always present, which
/// stopped the keyboard when read as a Swift `UUID`.
struct KeyboardDocumentIdentifierTests {
    private final class HostDocument: NSObject {
        @objc var documentIdentifier: NSUUID?

        init(documentIdentifier: NSUUID?) {
            self.documentIdentifier = documentIdentifier
        }
    }

    @Test func missingIdentifierReadsAsNil() {
        #expect(KeyboardDocumentIdentifier.read(from: HostDocument(documentIdentifier: nil)) == nil)
    }

    @Test func handedOverIdentifierReadsAsItself() {
        let identifier = UUID()
        let document = HostDocument(documentIdentifier: identifier as NSUUID)
        #expect(KeyboardDocumentIdentifier.read(from: document) == identifier)
    }

    @Test func proxyWithoutIdentifierReadsAsNil() {
        #expect(KeyboardDocumentIdentifier.read(from: NSObject()) == nil)
    }
}
