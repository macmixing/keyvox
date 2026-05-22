import Foundation

public enum KeyVoxVibesAdapterKind: String, CaseIterable, Sendable {
    case polished
    case casual
}

public struct KeyVoxVibesAdapterDescriptor: Equatable, Sendable {
    public let kind: KeyVoxVibesAdapterKind
    public let id: String
    public let filename: String
    public let compatibleBaseModelID: String

    public var resourceName: String {
        (filename as NSString).deletingPathExtension
    }

    public var resourceExtension: String {
        (filename as NSString).pathExtension
    }
}

public enum KeyVoxVibesAdapterCatalog {
    public static let compatibleBaseModelID = "qwen2-5-0-5b-instruct"
    public static let resourceSubdirectory = "Adapters"

    public static let polished = KeyVoxVibesAdapterDescriptor(
        kind: .polished,
        id: "polished-alpha-025",
        filename: "polished-alpha-025-lora.gguf",
        compatibleBaseModelID: compatibleBaseModelID
    )

    public static let casual = KeyVoxVibesAdapterDescriptor(
        kind: .casual,
        id: "casual-alpha-8",
        filename: "casual-alpha-8-lora.gguf",
        compatibleBaseModelID: compatibleBaseModelID
    )

    public static var allAdapters: [KeyVoxVibesAdapterDescriptor] {
        [polished, casual]
    }

    public static func descriptor(for kind: KeyVoxVibesAdapterKind) -> KeyVoxVibesAdapterDescriptor {
        switch kind {
        case .polished:
            return polished
        case .casual:
            return casual
        }
    }

    public static func url(for kind: KeyVoxVibesAdapterKind) -> URL? {
        let descriptor = descriptor(for: kind)
        return Bundle.module.url(
            forResource: descriptor.resourceName,
            withExtension: descriptor.resourceExtension,
            subdirectory: resourceSubdirectory
        )
    }
}
