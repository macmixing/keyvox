import SwiftUI
import KeyVoxCore

@main
struct KeyVoxApp: App {
    @StateObject private var transcriptionManager: iOSTranscriptionManager
    @StateObject private var modelManager: iOSModelManager
    @StateObject private var settingsStore: iOSAppSettingsStore
    private let urlRouter: KeyVoxURLRouter
    private let dictionaryStore: DictionaryStore

    init() {
        let services = iOSAppServiceRegistry.shared
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        _modelManager = StateObject(wrappedValue: services.modelManager)
        _settingsStore = StateObject(wrappedValue: services.settingsStore)
        urlRouter = services.urlRouter
        dictionaryStore = services.dictionaryStore
        iOSModelDownloadBackgroundTasks.register()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(transcriptionManager)
                .environmentObject(modelManager)
                .environmentObject(settingsStore)
                .environmentObject(dictionaryStore)
                .onOpenURL { url in
                    urlRouter.handle(url: url)
                }
        }
    }
}
