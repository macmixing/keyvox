import SwiftUI

extension SettingsView {
    var dictionaryTabSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 10)

            dictionarySettings

            HStack {
                Spacer()
                Text("Custom dictionary correction is currently supported for English only.", comment: "Note on the Dictionary page in Settings explaining that custom dictionary correction only works for English dictation.")
                    .font(.appFont(11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
