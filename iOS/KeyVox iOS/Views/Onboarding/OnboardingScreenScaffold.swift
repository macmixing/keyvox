import SwiftUI

struct OnboardingScreenScaffold<Content: View>: View {
    let title: String
    let actionTitle: String?
    let isActionEnabled: Bool
    let action: (() -> Void)?
    let content: Content

    init(
        title: String,
        actionTitle: String? = nil,
        isActionEnabled: Bool = true,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.isActionEnabled = isActionEnabled
        self.action = action
        self.content = content()
    }

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.appFont(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                content
            }
            .padding(.bottom, action == nil ? 24 : 112)
        }
        .safeAreaInset(edge: .bottom) {
            if let actionTitle, let action {
                VStack(spacing: 0) {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.appFont(18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(.yellow)
                    .foregroundStyle(.black)
                    .disabled(!isActionEnabled)
                }
                .padding(.horizontal, iOSAppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(iOSAppTheme.screenBackground.opacity(0.98))
            }
        }
    }
}
