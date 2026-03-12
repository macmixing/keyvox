import SwiftUI

struct UpdateHeaderCard: View {
    let currentVersion: String
    let targetVersion: String?
    let statusMessage: String
    let state: AppUpdateState

    private var badgeTitle: String {
        if let targetVersion, !targetVersion.isEmpty {
            return "v\(targetVersion)"
        }
        return "v\(currentVersion)"
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Updater")
                            .font(.custom("Kanit Medium", size: 18))
                            .foregroundColor(.white)
                        Text(statusMessage)
                            .font(.custom("Kanit Medium", size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    StatusBadge(title: badgeTitle, color: .indigo)
                }

                HStack {
                    Text("Current: v\(currentVersion)")
                        .font(.custom("Kanit Medium", size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let targetVersion, state != .completed {
                        Text("Update: v\(targetVersion)")
                            .font(.custom("Kanit Medium", size: 11))
                            .foregroundColor(.indigo)
                    }
                }
            }
        }
    }
}
