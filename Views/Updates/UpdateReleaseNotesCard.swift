import SwiftUI

struct UpdateReleaseNotesCard: View {
    let releaseNotes: String

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Release Notes")
                    .font(.appFont(15))
                    .foregroundColor(.white)

                Text(releaseNotes)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
