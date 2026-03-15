import SwiftUI

struct OnboardingRequirementRow: View {
    let title: String
    let detail: String
    let isComplete: Bool
    let actionTitle: String?
    let action: (() -> Void)?

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
                            .foregroundStyle(.secondary)
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
