import SwiftUI

extension View {
    /// On iPad, presents this sheet at the larger page size, so content written for a phone-height
    /// sheet fits. Other devices keep their sheet size.
    @ViewBuilder
    func appPadPageSheetSizing() -> some View {
        if AppDevice.isPad {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
