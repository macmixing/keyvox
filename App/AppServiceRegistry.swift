import Foundation
import KeyVoxCore

@MainActor
final class AppServiceRegistry {
    static let shared = AppServiceRegistry()

    let dictionaryStore: DictionaryStore
    let whisperService: WhisperService
    let iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator

    init(
        dictionaryStore: DictionaryStore,
        whisperService: WhisperService,
        iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator
    ) {
        self.dictionaryStore = dictionaryStore
        self.whisperService = whisperService
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
    }

    private init(fileManager: FileManager = .default) {
        let appSupportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KeyVox", isDirectory: true)
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/KeyVox", isDirectory: true)

        dictionaryStore = DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: appSupportRoot
        )
        whisperService = WhisperService(
            modelPathResolver: {
                let modelPath = appSupportRoot
                    .appendingPathComponent("Models", isDirectory: true)
                    .appendingPathComponent("ggml-base.bin")
                    .path
                return fileManager.fileExists(atPath: modelPath) ? modelPath : nil
            }
        )
        iCloudSyncCoordinator = KeyVoxiCloudSyncCoordinator(
            appSettings: .shared,
            dictionaryStore: dictionaryStore
        )
    }
}
