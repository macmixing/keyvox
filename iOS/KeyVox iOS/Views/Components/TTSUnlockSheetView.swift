import SwiftUI

struct TTSUnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController

    var body: some View {
        KeyVoxSpeakSheetView(
            mode: .unlock(
                onDismiss: dismissSheet
            )
        )
        .environmentObject(ttsPurchaseController)
    }

    private func dismissSheet() {
        ttsPurchaseController.dismissUnlockSheet()
        dismiss()
    }
}
