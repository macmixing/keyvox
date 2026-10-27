import SwiftUI

extension View {
    /// On iPad, leaves `length` of space under a sheet's bottom buttons, since a sheet there has no
    /// home indicator space below it. Other devices keep their layout.
    func appSheetBottomPadding(_ length: CGFloat) -> some View {
        padding(.bottom, AppDevice.isPad ? length : 0)
    }
}
