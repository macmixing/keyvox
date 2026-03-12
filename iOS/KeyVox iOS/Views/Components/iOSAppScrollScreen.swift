import SwiftUI

struct iOSAppScrollScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            iOSAppTheme.screenTint
                .background(iOSAppTheme.screenBase)
                .ignoresSafeArea()

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(iOSAppTheme.screenPadding)
            }
            .contentMargins(.top, -20, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}
