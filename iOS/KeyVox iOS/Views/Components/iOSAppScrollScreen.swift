import SwiftUI

struct iOSAppScrollScreen<Content: View>: View {
    let content: Content

    private var topContentInset: CGFloat {
        if #available(iOS 26.0, *) {
            return -20
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

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(iOSAppTheme.screenPadding)
            }
            .contentMargins(.top, topContentInset, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}
