import SwiftUI

struct KeyVoxVibesUnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
    private let initialScene: KeyVoxVibesSheetView.Scene
    private let primaryAction: KeyVoxVibesSheetView.UnlockPrimaryAction

    init(
        initialScene: KeyVoxVibesSheetView.Scene = .b,
        primaryAction: KeyVoxVibesSheetView.UnlockPrimaryAction = .purchase
    ) {
        self.initialScene = initialScene
        self.primaryAction = primaryAction
    }

    var body: some View {
        KeyVoxVibesSheetView(
            mode: .unlock(
                initialScene: initialScene,
                primaryAction: primaryAction,
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
