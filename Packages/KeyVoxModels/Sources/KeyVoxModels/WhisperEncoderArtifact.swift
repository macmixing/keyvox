import Foundation

/// A compiled encoder paired with the existing Base weights. Installation is
/// host-owned and optional: failure must not prevent ordinary Base inference.
public struct WhisperEncoderArtifact: Sendable {
    public let downloadURL: URL
    public let archiveSHA256: String
    public let archiveMember: String
    public let filename: String
    public let sha256: String
    public let byteCount: Int64
    public let baseModelSHA256: String

    /// Only targets with a verified artifact are selected. Other hardware keeps
    /// the native encoder until its corresponding artifact has been validated.
    public static func qualcommArtifact(socIdentifier: String) -> Self? {
        guard socIdentifier.uppercased() == "SM8850" else { return nil }
        let asset = "whisper_base-qnn_context_binary-float-qualcomm_snapdragon_8_elite_gen5_for_galaxy"
        return Self(
            downloadURL: URL(string: "https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/whisper_base/releases/v0.61.0/\(asset).zip")!,
            archiveSHA256: "b5ee2b89ae84ba5ef14496a6238657d23f98e4987fb33374933edde94d11da60",
            archiveMember: "\(asset)/encoder.bin",
            filename: "\(asset)-encoder.bin",
            sha256: "3dd452e263294fc04f239d631b628bafcf3369422c69af351ae91acb090a02e3",
            byteCount: 49_827_840,
            // This pairing belongs to this compiled release, independently of future Base catalog updates.
            baseModelSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")
    }
}
