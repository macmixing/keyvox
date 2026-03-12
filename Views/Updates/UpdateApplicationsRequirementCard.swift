import SwiftUI

struct UpdateApplicationsRequirementCard: View {
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Move KeyVox To Applications")
                    .font(.appFont(15))
                    .foregroundColor(.white)

                Text("KeyVox will copy itself into Applications, relaunch there, and resume the updater automatically.")
                    .font(.appFont(12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
