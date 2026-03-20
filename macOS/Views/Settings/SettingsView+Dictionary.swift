import SwiftUI

extension SettingsView {
    var dictionaryTabSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 10)

            dictionarySettings

            HStack {
                Spacer()
                Text("Custom dictionary correction is currently supported for English only.")
                    .font(.appFont(11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
