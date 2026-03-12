import Combine
import SwiftUI

struct iOSAppIconTile: View {
    let systemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(iOSAppTheme.iconFill)
                .frame(width: 44, height: 44)

            Image(systemName: systemImage)
                .font(.appFont(20))
                .foregroundStyle(iOSAppTheme.accent)
        }
        .accessibilityHidden(true)
    }
}
