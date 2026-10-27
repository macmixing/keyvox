import SwiftUI

extension View {
    /// On iPad, centers this view in a column no wider than the app's readable content width, so
    /// it doesn't stretch edge to edge on wide windows. `horizontalPadding` is the padding this
    /// view already has on each side, which the column makes room for. Other devices keep their
    /// full-width layout.
    @ViewBuilder
    func appReadableWidth(horizontalPadding: CGFloat = 0) -> some View {
        if AppDevice.isPad {
            frame(maxWidth: AppTheme.readableContentWidth + horizontalPadding * 2)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }
}
