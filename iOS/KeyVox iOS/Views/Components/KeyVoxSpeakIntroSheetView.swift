import SwiftUI

struct KeyVoxSpeakIntroSheetView: View {
    private struct IntroPage: Identifiable {
        let id: Int
        let title: String
        let body: String
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @State private var selectedPage = 0

    private let pages = [
        IntroPage(
            id: 0,
            title: "KeyVox Speak",
            body: "A new copied-text playback feature is now available in KeyVox."
        ),
        IntroPage(
            id: 1,
            title: "Listen Anywhere",
            body: "Speak copied text from the app and jump back into replay whenever you want to hear it again."
        ),
        IntroPage(
            id: 2,
            title: "Designed To Grow",
            body: "This intro is intentionally lightweight for now while the final KeyVox Speak presentation is still being designed."
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $selectedPage) {
                        ForEach(pages) { page in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(page.title)
                                    .font(.appFont(26))
                                    .foregroundStyle(.white)

                                Text(page.body)
                                    .font(.appFont(16, variant: .light))
                                    .foregroundStyle(.white.opacity(0.78))

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 24)
                            .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    VStack(spacing: 0) {
                        Divider()
                            .background(.white.opacity(0.14))

                        AppActionButton(
                            title: "Try KeyVox Speak",
                            style: .primary,
                            fillsWidth: true,
                            size: .compact,
                            fontSize: 15,
                            action: dismissIntro
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(AppTheme.screenBackground)
                }
            }
            .navigationTitle("")
        }
    }

    private func dismissIntro() {
        keyVoxSpeakIntroController.dismiss()
        dismiss()
    }
}
