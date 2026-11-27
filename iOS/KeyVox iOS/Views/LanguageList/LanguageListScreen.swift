import SwiftUI

/// A full-screen list of languages to choose from: the caller's header, a search field, the
/// languages in a card of rows with check circles, and an action button at the bottom that stays
/// disabled until a language is checked.
struct LanguageListScreen<Header: View>: View {
    /// Which languages are checked.
    enum Selection {
        /// One language at a time; checking one unchecks the one before.
        case single(Binding<String?>)
    }

    @Environment(\.appHaptics) private var appHaptics
    @State private var searchText = ""
    private let options: [LanguageListOption]
    private let selection: Selection
    private let actionTitle: String
    private let isSearchFocused: FocusState<Bool>.Binding
    private let ignoresLanguageTaps: Bool
    private let onAction: () -> Void
    private let header: Header

    /// - Parameters:
    ///   - options: The languages, in the order the list shows them.
    ///   - ignoresLanguageTaps: Whether taps on languages do nothing, as while the screen moves on.
    init(
        options: [LanguageListOption],
        selection: Selection,
        actionTitle: String,
        isSearchFocused: FocusState<Bool>.Binding,
        ignoresLanguageTaps: Bool = false,
        onAction: @escaping () -> Void,
        @ViewBuilder header: () -> Header
    ) {
        self.options = options
        self.selection = selection
        self.actionTitle = actionTitle
        self.isSearchFocused = isSearchFocused
        self.ignoresLanguageTaps = ignoresLanguageTaps
        self.onAction = onAction
        self.header = header()
    }

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 20) {
                header

                LanguageListSearchField(text: $searchText, isFocused: isSearchFocused)

                optionsCard(filteredOptions)
            }
            .padding(.bottom, 92)
        }
        .safeAreaInset(edge: .bottom) {
            AppActionButton(
                title: actionTitle,
                style: .primary,
                fillsWidth: true,
                fontSize: 20,
                isEnabled: hasSelection,
                action: onAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .appReadableWidth(horizontalPadding: AppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppTheme.screenBackground.opacity(0.98))
        }
    }

    private func optionsCard(_ shownOptions: [LanguageListOption]) -> some View {
        AppCard(
            contentInsets: EdgeInsets(
                top: 0,
                leading: AppTheme.cardPadding,
                bottom: 4,
                trailing: AppTheme.cardPadding
            )
        ) {
            LazyVStack(spacing: 0) {
                ForEach(Array(shownOptions.enumerated()), id: \.element.id) { index, option in
                    LanguageListRow(name: option.name, isChecked: isChecked(option)) {
                        toggle(option)
                    }

                    if index < shownOptions.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.14))
                    }
                }

                if shownOptions.isEmpty {
                    Text("No languages found", comment: "Empty state on a language list screen when the search matches nothing.")
                        .font(.appFont(16, variant: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    private var filteredOptions: [LanguageListOption] {
        guard !searchText.isEmpty else { return options }
        return options.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var hasSelection: Bool {
        switch selection {
        case let .single(selected):
            selected.wrappedValue != nil
        }
    }

    private func isChecked(_ option: LanguageListOption) -> Bool {
        switch selection {
        case let .single(selected):
            selected.wrappedValue == option.id
        }
    }

    private func toggle(_ option: LanguageListOption) {
        guard ignoresLanguageTaps == false else { return }
        appHaptics.light()
        switch selection {
        case let .single(selected):
            selected.wrappedValue = option.id
        }
    }
}
