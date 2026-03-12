import Foundation
import CryptoKit

struct AppUpdateChecksumVerifier {
    func verify(fileURL: URL, expectedSHA256: String) throws {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        guard hash == expectedSHA256.lowercased() else {
            throw AppUpdateError.checksumMismatch
        }
    }
}
