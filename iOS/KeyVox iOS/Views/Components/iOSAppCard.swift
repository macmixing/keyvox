import SwiftUI

struct iOSAppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(iOSAppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: iOSAppTheme.cardCornerRadius)
                    .fill(iOSAppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: iOSAppTheme.cardCornerRadius)
                            .stroke(iOSAppTheme.cardStroke, lineWidth: 1)
                    )
            )
    }
}
