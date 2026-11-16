import Foundation

/// The approximate head start Fast Mode gives KeyVox Speak, as the Speak pages quote it.
enum KeyVoxSpeakFastModeSpeedup {
    private static let fraction = 0.5

    /// The speedup as a percentage written the way the current language writes percentages.
    static var formattedPercent: String {
        fraction.formatted(.percent)
    }
}
