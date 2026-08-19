import SwiftUI

enum AppScreenContentInset {
    static let tabPageTop: CGFloat = 20
}

struct AppScrollScreen<Content: View>: View {
    let content: Content
    let scrollDisabled: Bool
    let additionalTopContentInset: CGFloat

    static var sharedTopContentInset: CGFloat {
        if #available(iOS 26.0, *) {
            return -10
        } else {
            return 12
        }
    }

    init(
        scrollDisabled: Bool = false,
        additionalTopContentInset: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.scrollDisabled = scrollDisabled
        self.additionalTopContentInset = additionalTopContentInset
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
            .contentMargins(
                .top,
                Self.sharedTopContentInset + additionalTopContentInset,
                for: .scrollContent
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}
