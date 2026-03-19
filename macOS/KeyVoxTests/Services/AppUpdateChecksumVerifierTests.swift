import Foundation
import XCTest
@testable import KeyVox

final class AppUpdateChecksumVerifierTests: XCTestCase {
    func testVerifyAcceptsMatchingChecksum() throws {
        try withTemporaryDirectory { root in
            let fileURL = root.appendingPathComponent("payload.zip")
            let data = Data("hello".utf8)
            try data.write(to: fileURL)

            let verifier = AppUpdateChecksumVerifier()
            try verifier.verify(
                fileURL: fileURL,
                expectedSHA256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
            )
        }
    }

    func testVerifyRejectsMismatchedChecksum() throws {
        try withTemporaryDirectory { root in
            let fileURL = root.appendingPathComponent("payload.zip")
            try Data("hello".utf8).write(to: fileURL)

            let verifier = AppUpdateChecksumVerifier()
            XCTAssertThrowsError(
                try verifier.verify(
                    fileURL: fileURL,
                    expectedSHA256: "deadbeef"
                )
            )
        }
    }
}
