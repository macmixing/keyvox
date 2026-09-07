import Foundation
import KeyVoxParakeet

extension ParakeetService {
    /// Selects an inference implementation without coupling Core to its native library.
    public convenience init(
        modelURLResolver: @escaping () -> URL?,
        backendFactory: @escaping @Sendable (URL) throws -> (any ParakeetRuntimeBackend)?
    ) {
        self.init(modelURLResolver: modelURLResolver, parakeetLoader: { modelURL in
            try Parakeet(fromModelURL: modelURL, backendFactory: backendFactory)
        })
    }
}
