import SwiftUI
import KeyVoxStyleRewrite

extension StyleTabView {
    @ViewBuilder
    var keyVoxVibesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 4) {
                            Text("KeyVox Vibes")
                                .font(.appFont(18))
                                .foregroundStyle(.white)

                            Button(action: handleVibesHelpAction) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 16, height: 16)
                                    .contentShape(Rectangle())
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 32, height: 32)
                            .accessibilityLabel("Learn about KeyVox Vibes")
                        }

                        Text(displayedSelectedVibe.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Picker("", selection: keyVoxVibesSelection) {
                            ForEach(StyleRewriteStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Text("Change")
                            .font(.appFont(16))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                HStack(alignment: .top, spacing: 12) {
                    Text(keyVoxVibesDescription)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appHaptics.light()
                        withAnimation(Self.sectionExpansionAnimation) {
                            isVibeExamplesExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isVibeExamplesExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.yellow)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isVibeExamplesExpanded ? "Hide vibe examples" : "Show vibe examples")
                }

                keyVoxVibesUnlockSection

                vibeExamplesExpandedContent
                    .frame(height: isVibeExamplesExpanded ? vibeExamplesExpandedContentHeight : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(isVibeExamplesExpanded)
                    .accessibilityHidden(!isVibeExamplesExpanded)
                    .background(alignment: .top) {
                        if isVibeExamplesExpanded || vibeExamplesExpandedContentHeight == 0 {
                            vibeExamplesExpandedContentMeasurement
                        }
                    }

            }
        }
    }

    private var vibeExamplesExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(vibeExamples.enumerated()), id: \.element.style) { index, example in
                    vibeExampleRow(example)

                    if index < vibeExamples.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.22))
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                    }
                }
            }

            Text("Vibes are currently supported for English only.")
                .font(.appFont(13, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var vibeExamplesExpandedContentMeasurement: some View {
        vibeExamplesExpandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateVibeExamplesExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateVibeExamplesExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    private func vibeExampleRow(_ example: VibeExample) -> some View {
        Button {
            appHaptics.light()
            selectVibe(example.style)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(example.style.displayName)
                        .font(.appFont(17))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(example.text)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: example.style == displayedSelectedVibe ? "checkmark.circle.fill" : "checkmark.circle.dotted")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(example.style == displayedSelectedVibe ? .green : .white)
            }
            .padding(.leading, 10)
            .padding(.trailing, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private func updateVibeExamplesExpandedContentHeight(_ newHeight: CGFloat) {
        guard abs(vibeExamplesExpandedContentHeight - newHeight) > 0.5 else { return }
        vibeExamplesExpandedContentHeight = newHeight
    }

    private var vibeExamples: [VibeExample] {
        StyleRewriteStyle.allCases.map { style in
            VibeExample(style: style, text: style.exampleText)
        }
    }

    private struct VibeExample: Hashable {
        let style: StyleRewriteStyle
        let text: String
    }

    private var keyVoxVibesDescription: String {
        displayedSelectedVibe.description
    }

    private var keyVoxVibesSelection: Binding<StyleRewriteStyle> {
        Binding(
            get: { displayedSelectedVibe },
            set: { newValue in
                selectVibe(newValue)
            }
        )
    }

    @ViewBuilder
    private var keyVoxVibesUnlockSection: some View {
        if !keyVoxVibesPurchaseController.isVibesUnlocked {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("KeyVox Vibes Unlock")
                        .font(.appFont(17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: vibesUnlockButtonTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        isEnabled: keyVoxVibesPurchaseController.isStoreActionInFlight == false,
                        action: handleVibesUnlockAction
                    )
                }

                Text(vibesUnlockStatusText)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var displayedSelectedVibe: StyleRewriteStyle {
        keyVoxVibesPurchaseController.canUseVibes ? settingsStore.selectedVibe : .none
    }

    private var vibesUnlockButtonTitle: String {
        keyVoxVibesPurchaseController.hasTrialStarted ? "Unlock" : "Try Now"
    }

    private var vibesUnlockStatusText: String {
        if keyVoxVibesPurchaseController.isTrialActive {
            return "You’re using Vibes for a day, you have \(keyVoxVibesPurchaseController.trialRemainingText) left."
        }

        if keyVoxVibesPurchaseController.hasTrialEnded {
            return "Unlock KeyVox Vibes once and use it for life."
        }

        return "Try out KeyVox Vibes for 24 hours."
    }

    private func selectVibe(_ style: StyleRewriteStyle) {
        guard style != .none else {
            settingsStore.selectedVibe = .none
            return
        }

        guard keyVoxVibesPurchaseController.canUseVibes else {
            settingsStore.selectedVibe = .none
            keyVoxVibesPurchaseController.presentIntroSheet()
            return
        }

        keyVoxVibesPurchaseController.markVibesInteracted()
        settingsStore.selectedVibe = style
    }

    private func handleVibesUnlockAction() {
        appHaptics.light()
        if keyVoxVibesPurchaseController.hasTrialStarted {
            keyVoxVibesPurchaseController.presentUnlockSheet()
        } else {
            keyVoxVibesPurchaseController.presentIntroSheet()
        }
    }

    private func handleVibesHelpAction() {
        appHaptics.light()
        keyVoxVibesPurchaseController.presentHelpSheet()
    }
}
