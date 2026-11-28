import SwiftUI

/// A settings row that shows what a setting is set to: an icon, a title, the current value under
/// it, and trailing content such as a Change button beside the title.
struct SettingsValueRow<TrailingContent: View>: View {
    let icon: String
    let title: String
    let value: String
    @ViewBuilder let trailingContent: TrailingContent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(18))
                    .foregroundStyle(.white)

                Text(verbatim: value)
                    .font(.appFont(17))
                    .foregroundStyle(.yellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
                .padding(.top, 2)
        }
    }
}
