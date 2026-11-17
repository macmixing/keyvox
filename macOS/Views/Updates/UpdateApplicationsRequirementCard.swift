import SwiftUI

struct UpdateApplicationsRequirementCard: View {
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Move KeyVox To Applications", comment: "Title of the card in the KeyVox update window when the app must be moved into the Applications folder before updating. Applications is the macOS Applications folder; use the name macOS uses in this language. KeyVox is a brand name and stays in English.")
                    .font(.appFont(15))
                    .foregroundColor(.white)

                Text("KeyVox will copy itself into Applications, relaunch there, and resume the updater automatically.", comment: "Message of the card in the KeyVox update window when the app must be moved into the Applications folder before updating. Applications is the macOS Applications folder; use the name macOS uses in this language. KeyVox is a brand name and stays in English.")
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
