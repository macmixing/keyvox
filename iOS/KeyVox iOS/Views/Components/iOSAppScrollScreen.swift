import SwiftUI

struct iOSAppScrollScreen<Content: View>: View {
    let content: Content

    static var sharedTopContentInset: CGFloat {
        if #available(iOS 26.0, *) {
            return -10
        } else {
            return 12
        }
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            iOSAppTheme.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(iOSAppTheme.screenPadding)
            }
            .contentMargins(.top, Self.sharedTopContentInset, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}
