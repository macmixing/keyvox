import SwiftUI

struct KeyVoxSpeakIntroSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController

    var body: some View {
        KeyVoxSpeakSheetView(
            mode: .intro(
                onTryNow: dismissIntro
            )
        )
        .environmentObject(ttsPurchaseController)
    }

    private func dismissIntro() {
        keyVoxSpeakIntroController.dismiss()
        dismiss()
    }
}
