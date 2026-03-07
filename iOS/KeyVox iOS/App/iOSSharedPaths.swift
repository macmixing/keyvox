import Foundation

nonisolated enum iOSSharedPaths {
    static let appGroupID = "group.com.cueit.keyvox"

    static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func modelFileURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("ggml-base.bin")
    }

    static func dictionaryBaseDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("KeyVoxCore", isDirectory: true)
    }

    static func fallbackBaseDirectoryURL(fileManager: FileManager = .default) -> URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupportDirectory.appendingPathComponent("KeyVoxFallback", isDirectory: true)
    }
}
