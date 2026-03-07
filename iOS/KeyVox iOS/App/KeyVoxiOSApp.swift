import SwiftUI

@main
struct KeyVoxApp: App {
    @StateObject private var transcriptionManager: iOSTranscriptionManager
    private let urlRouter: KeyVoxURLRouter

    init() {
        let services = iOSAppServiceRegistry.shared
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        urlRouter = services.urlRouter
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(transcriptionManager)
                .onOpenURL { url in
                    urlRouter.handle(url: url)
                }
        }
    }
}
