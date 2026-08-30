import SwiftUI

struct DictationShortcutSetupPageView: View {
    let page: DictationShortcutSetupPage

    var body: some View {
        ZStack {
            if page.includesVideoPlaceholder {
                DictationShortcutSetupVideoPlaceholder(page: page)
                    .frame(maxWidth: 350)
                    .padding(.horizontal, AppTheme.screenPadding)
            }

            Text("Page \(page.rawValue)")
                .font(.appFont(34, variant: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 36)
                .padding(.horizontal, AppTheme.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
