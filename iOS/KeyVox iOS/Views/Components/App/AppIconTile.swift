import Combine
import SwiftUI

struct AppIconTile: View {
    let systemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.iconFill)
                .frame(width: 44, height: 44)

            Image(systemName: systemImage)
                .font(.appFont(20))
                .foregroundStyle(AppTheme.accent)
        }
        .accessibilityHidden(true)
    }
}
