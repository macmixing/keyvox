import SwiftUI

struct UpdateReleaseNotesCard: View {
    let releaseNotes: String

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Release Notes")
                    .font(.custom("Kanit Medium", size: 15))
                    .foregroundColor(.white)

                Text(releaseNotes)
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
