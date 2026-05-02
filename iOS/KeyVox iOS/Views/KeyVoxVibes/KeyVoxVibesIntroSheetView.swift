import SwiftUI

struct KeyVoxVibesIntroSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var keyVoxVibesIntroController: KeyVoxVibesIntroController
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController

    var body: some View {
        KeyVoxVibesSheetView(
            mode: .intro(
                presentation: keyVoxVibesIntroController.introPresentation,
                onTryNow: startTrial,
                onDismiss: dismissIntro
            )
        )
        .environmentObject(vibesPurchaseController)
    }

    private func startTrial() {
        keyVoxVibesIntroController.dismiss()
        vibesPurchaseController.startTrial()
        dismiss()
    }

    private func dismissIntro() {
        keyVoxVibesIntroController.dismiss()
        dismiss()
    }
}
