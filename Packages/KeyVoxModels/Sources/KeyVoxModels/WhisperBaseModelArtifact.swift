import Foundation

/// The existing KeyVox Base weights, shared by every host that installs Whisper.
/// Platform acceleration assets and installation state remain host-owned.
public enum WhisperBaseModelArtifact {
    public static let revision = "90a64d80ea254cf67575b41a5971f972c79f7b45"
    public static let filename = "ggml-base.bin"
    public static let sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
    public static let downloadURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/\(revision)/\(filename)"
    )!
}
