import Combine
import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content
    let contentInsets: EdgeInsets

    init(
        contentInsets: EdgeInsets = EdgeInsets(
            top: AppTheme.cardPadding,
            leading: AppTheme.cardPadding,
            bottom: AppTheme.cardPadding,
            trailing: AppTheme.cardPadding
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.contentInsets = contentInsets
    }

    var body: some View {
        content
            .padding(contentInsets)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(AppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    )
            )
    }
}
