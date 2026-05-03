import SwiftUI

struct KeyVoxVibesUnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController

    var body: some View {
        KeyVoxVibesSheetView(
            mode: .unlock(
                onDismiss: dismissSheet
            )
        )
        .environmentObject(vibesPurchaseController)
    }

    private func dismissSheet() {
        vibesPurchaseController.dismissSheet()
        dismiss()
    }
}
