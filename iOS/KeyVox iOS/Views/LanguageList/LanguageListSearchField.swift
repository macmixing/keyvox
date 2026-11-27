import SwiftUI

/// The search field at the top of a language list.
struct LanguageListSearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.5))

            TextField(String(localized: "Search languages", comment: "Placeholder for the search field on a language list screen."), text: $text)
                .font(.appFont(17, variant: .light))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(AppTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}
