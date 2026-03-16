import SwiftUI

struct OnboardingRequirementRow: View {
    let title: String
    let detail: String
    let isComplete: Bool
    let detailColor: Color
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        detail: String,
        isComplete: Bool,
        detailColor: Color = .secondary,
        actionTitle: String?,
        action: (() -> Void)?
    ) {
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.detailColor = detailColor
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isComplete ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.appFont(17))
                            .foregroundStyle(.white)

                        Text(detail)
                            .font(.appFont(13, variant: .light))
                            .foregroundStyle(detailColor)
                    }

                    Spacer(minLength: 0)
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .tint(.indigo.opacity(0.8))
                        .font(.appFont(14, variant: .light))
                }
            }
        }
    }
}
