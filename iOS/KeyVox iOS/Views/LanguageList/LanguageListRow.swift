import SwiftUI

/// One language in a language list: its name and a check circle, the whole row a button.
struct LanguageListRow: View {
    let name: String
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(name)
                    .font(.appFont(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isChecked ? .yellow : .white.opacity(0.3))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}
