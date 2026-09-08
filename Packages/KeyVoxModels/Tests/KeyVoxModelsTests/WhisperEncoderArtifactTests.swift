import XCTest
@testable import KeyVoxModels

final class WhisperEncoderArtifactTests: XCTestCase {
    func testUnknownHardwareRetainsNativeEncoder() {
        XCTAssertNil(WhisperEncoderArtifact.qualcommArtifact(socIdentifier: ""))
        XCTAssertNil(WhisperEncoderArtifact.qualcommArtifact(socIdentifier: UUID().uuidString))
    }
    func testVerifiedArtifactIsPairedWithBaseAndIntegrityChecked() throws {
        let artifact = try XCTUnwrap(WhisperEncoderArtifact.qualcommArtifact(socIdentifier: "SM8850"))
        XCTAssertEqual(artifact.baseModelSHA256, WhisperBaseModelArtifact.sha256)
        XCTAssertEqual(artifact.downloadURL.scheme, "https")
        XCTAssertGreaterThan(artifact.byteCount, 0)
        for digest in [artifact.sha256, artifact.archiveSHA256] {
            XCTAssertEqual(digest.count, 64)
            XCTAssertTrue(digest.allSatisfy { $0.isHexDigit })
        }
        XCTAssertFalse(artifact.filename.contains("/"))
        XCTAssertEqual(WhisperEncoderArtifact.qualcommArtifact(socIdentifier: "sm8850")?.sha256, artifact.sha256)
    }
}
