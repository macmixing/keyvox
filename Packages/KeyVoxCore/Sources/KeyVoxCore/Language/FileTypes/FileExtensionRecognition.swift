#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

enum FileExtensionRecognition {
    static func status(for fileExtension: String) -> FileExtensionStatus {
        #if canImport(UniformTypeIdentifiers)
        guard let type = UTType(filenameExtension: fileExtension) else { return .unknown }
        return type.identifier.hasPrefix("dyn.") ? .unknown : .known
        #else
        return portableStatus(for: fileExtension)
        #endif
    }

    static func portableStatus(for fileExtension: String) -> FileExtensionStatus {
        switch FileExtensionRegistry.bundled {
        case let .success(registry):
            return registry.recognizes(fileExtension) ? .known : .unknown
        case .failure:
            return .unavailable
        }
    }
}
