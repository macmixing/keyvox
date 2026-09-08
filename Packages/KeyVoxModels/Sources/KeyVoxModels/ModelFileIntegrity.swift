import Foundation
import Crypto

/// Streams model bytes through SHA-256 without owning download or installation state.
public enum ModelFileIntegrity {
    public static func sha256Hex(
        forFileAt url: URL,
        progress: ((Int64, Int64) -> Void)? = nil
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        var completedBytes: Int64 = 0
        var hasher = SHA256()
        progress?(0, totalBytes)
        while try withReadPool({
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { return false }
            hasher.update(data: data)
            completedBytes += Int64(data.count)
            progress?(completedBytes, totalBytes)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func withReadPool<T>(_ body: () throws -> T) rethrows -> T {
        #if canImport(ObjectiveC)
        return try autoreleasepool(invoking: body)
        #else
        return try body()
        #endif
    }
}
