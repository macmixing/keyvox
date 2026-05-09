import SwiftUI

struct KeyVoxVibesUnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
    private let initialScene: KeyVoxVibesSheetView.Scene

    init(initialScene: KeyVoxVibesSheetView.Scene = .b) {
        self.initialScene = initialScene
    }

    var body: some View {
        KeyVoxVibesSheetView(
            mode: .unlock(
                initialScene: initialScene,
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
