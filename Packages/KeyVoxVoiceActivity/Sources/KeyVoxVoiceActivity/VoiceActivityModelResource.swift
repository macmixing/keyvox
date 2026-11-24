import Foundation

/// The bundled voice activity model every detector in this package loads.
enum VoiceActivityModelResource {
    static var bundledURL: URL? {
        Bundle.module.url(
            forResource: "ggml-silero-v5.1.2",
            withExtension: "bin"
        )
    }
}
