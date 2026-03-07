import SwiftUI

@main
struct KeyVoxApp: App {
    @StateObject private var transcriptionManager: iOSTranscriptionManager
    @StateObject private var modelManager: iOSModelManager
    private let urlRouter: KeyVoxURLRouter

    init() {
        let services = iOSAppServiceRegistry.shared
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        _modelManager = StateObject(wrappedValue: services.modelManager)
        urlRouter = services.urlRouter
        iOSModelDownloadBackgroundTasks.register()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(transcriptionManager)
                .environmentObject(modelManager)
                .onOpenURL { url in
                    urlRouter.handle(url: url)
                }
        }
    }
}
