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
                        Text("Updater")
                            .font(.appFont(18))
                            .foregroundColor(.white)
                        Text(statusMessage)
                            .font(.appFont(12))
                            .foregroundColor(.secondary)
                    }

                }

                HStack {
                    Text("Current: v\(currentVersion)")
                        .font(.appFont(11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let targetVersion, state != .completed {
                        Text("Update: v\(targetVersion)")
                            .font(.appFont(11))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }
}
