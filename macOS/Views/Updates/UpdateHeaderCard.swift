import SwiftUI

struct UpdateHeaderCard: View {
    let currentVersion: String
    let targetVersion: String?
    let statusMessage: String
    let state: AppUpdateState

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Updater", comment: "Title at the top of the KeyVox update window.")
                            .font(.appFont(18))
                            .foregroundColor(.white)
                        Text(statusMessage)
                            .font(.appFont(12))
                            .foregroundColor(.secondary)
                    }

                }

                HStack {
                    Text("Current: v\(currentVersion)", comment: "Installed app version in the KeyVox update window. %@ is the version number after the letter v.")
                        .font(.appFont(11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let targetVersion, state != .completed {
                        Text("Update: v\(targetVersion)", comment: "Available update version in the KeyVox update window. %@ is the version number after the letter v.")
                            .font(.appFont(11))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }
}
