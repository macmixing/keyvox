import Foundation

/// Approximate download sizes shown before a download, written with the user's language's units.
enum ApproximateDownloadSize {
    static let whisperBaseBytes: Int64 = 190_000_000
    static let parakeetBytes: Int64 = 335_000_000
    static let vibesAIBytes: Int64 = 491_000_000

    static var whisperBase: String { text(for: whisperBaseBytes) }
    static var parakeet: String { text(for: parakeetBytes) }
    static var vibesAI: String { text(for: vibesAIBytes) }

    static func text(for bytes: Int64) -> String {
        AppTypography.fontSupportedSpacing("~" + bytes.formatted(.byteCount(style: .file, allowedUnits: .mb)))
    }
}
