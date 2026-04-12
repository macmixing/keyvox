import SwiftUI

struct AppScrollScreen<Content: View>: View {
    let content: Content
    let scrollDisabled: Bool

    static var sharedTopContentInset: CGFloat {
        if #available(iOS 26.0, *) {
            return -10
        } else {
            return 12
        }
    }

    init(scrollDisabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.scrollDisabled = scrollDisabled
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.screenPadding)
            }
            .scrollDisabled(scrollDisabled)
            .contentMargins(.top, Self.sharedTopContentInset, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}
