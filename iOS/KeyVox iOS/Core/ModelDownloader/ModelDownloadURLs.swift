import Foundation

nonisolated enum ModelDownloadURLs {
    static let ggmlBase = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
    static let coreMLZip = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip")!
}
