import Foundation
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

                        Image("vibes-logo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundStyle(.yellow)
                            .frame(width: 18, height: 18)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(verbatim: "KeyVox Vibes")
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
                            .accessibilityLabel(String(localized: "Learn about KeyVox Vibes", comment: "VoiceOver label for the help button next to the KeyVox Vibes title on the Style tab. KeyVox Vibes is a brand name and stays in English."))
                        }

                        if shouldShowVibeSelector {
                            Text(displayedSelectedVibe.displayName)
                                .font(.appFont(17))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if shouldShowVibeSelector {
                        Menu {
                            Picker("", selection: keyVoxVibesSelection) {
                                ForEach(StyleRewriteStyle.allCases) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Text("Change", comment: "Menu button on the KeyVox Vibes card that opens the list of vibes.")
                                .font(.appFont(16))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.top, 2)
                    } else if let actionTitle = keyVoxVibesActionTitle {
                        AppActionButton(
                            title: actionTitle,
                            style: .primary,
                            size: .compact,
                            fontSize: 15,
                            isEnabled: isKeyVoxVibesActionEnabled,
                            action: handleKeyVoxVibesCardAction
                        )
                        .padding(.top, 2)
                    }
                }

                if let statusText = keyVoxVibesStatusText {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(statusText)
                                .font(.appFont(15, variant: .light))
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if case .downloading(let progress) = localRewriteModelManager.installState {
                                Text(progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)))
                                    .font(.appFont(14, variant: .medium))
                                    .foregroundStyle(.yellow)
                            }
                        }

                        if case .downloading(let progress) = localRewriteModelManager.installState {
                            ModelDownloadProgress(progress: progress, showLabel: false)
                        }
                    }
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
                    .accessibilityLabel(
                        isVibeExamplesExpanded
                            ? String(localized: "Hide vibe examples", comment: "VoiceOver label for the button that collapses the vibe examples on the Style tab. A vibe is one of the KeyVox Vibes rewrite styles.")
                            : String(localized: "Show vibe examples", comment: "VoiceOver label for the button that expands the vibe examples on the Style tab. A vibe is one of the KeyVox Vibes rewrite styles.")
                    )
                }

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

            Text(StyleRewriteStyle.languageSupportNote)
                .font(.appFont(13, variant: .light))
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(example.text)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white)
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
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

    private func updateVibeExamplesExpandedContentHeight(_ newHeight: CGFloat) {
        guard abs(vibeExamplesExpandedContentHeight - newHeight) > 0.5 else { return }
        vibeExamplesExpandedContentHeight = newHeight
    }

    private var vibeExamples: [VibeExample] {
        StyleRewriteStyle.allCases.map { style in
            VibeExample(style: style, text: style.exampleText(for: activeStyleRewriteDictationModel))
        }
    }

    private var activeStyleRewriteDictationModel: StyleRewriteDictationModel {
        settingsStore.activeDictationProvider.styleRewriteDictationModel
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

    private var displayedSelectedVibe: StyleRewriteStyle {
        keyVoxVibesMatrix.displayedSelectedVibe
    }

    private var isVibesAIInstalled: Bool {
        localRewriteModelManager.isModelReady()
    }

    private var shouldShowVibeSelector: Bool {
        keyVoxVibesMatrix.showsVibeSelector
    }

    private var keyVoxVibesStatusText: String? {
        if case .downloading = localRewriteModelManager.installState {
            return String(localized: "Downloading KeyVox Vibes AI...", comment: "Status on the KeyVox Vibes card on the Style tab while the model downloads. KeyVox Vibes AI is a brand name and stays in English.")
        }

        if keyVoxVibesMatrix.dynamicText == .mainCardTrialRemaining {
            let remainingText = KeyVoxVibesTrialRemainingTimeFormatter.remainingText(
                for: keyVoxVibesPurchaseController.trialRemaining
            )
            return String(localized: "You’re trying Vibes, you have \(remainingText) left.", comment: "Status on the KeyVox Vibes card during the free trial. Vibes is a brand name and stays in English. The placeholder is the remaining trial time, already formatted with its unit.")
        }

        switch keyVoxVibesMatrix.mainCardContent {
        case .downloadRequired:
            return String(localized: "Download Vibes AI to use Vibes.", comment: "Status on the KeyVox Vibes card when the model is not installed. Vibes AI and Vibes are brand names and stay in English.")
        case .unlockOffer:
            return String(localized: "Unlock and keep the Vibes flowing.", comment: "Status on the KeyVox Vibes card after the free trial, inviting the user to buy. Vibes is a brand name and stays in English; a playful tone is fine.")
        case .trialOffer:
            return String(localized: "Try KeyVox Vibes for free.", comment: "Status on the KeyVox Vibes card before the free trial starts. KeyVox Vibes is a brand name and stays in English.")
        case .selectedVibe:
            return nil
        }
    }

    private var keyVoxVibesActionTitle: String? {
        switch keyVoxVibesMatrix.cardControl {
        case .change:
            return nil
        case .download:
            return String(localized: "Download", comment: "Button on the KeyVox Vibes card that downloads the Vibes AI model.")
        case .unlock:
            return String(localized: "Unlock", comment: "Button on the KeyVox Vibes card that opens the purchase.")
        case .tryNow:
            return String(localized: "Try Now", comment: "Button on the KeyVox Vibes card that starts the free trial.")
        }
    }

    private var isKeyVoxVibesActionEnabled: Bool {
        guard keyVoxVibesPurchaseController.hasTrialStarted,
              keyVoxVibesPurchaseController.canUseVibes == false else {
            return true
        }

        return keyVoxVibesPurchaseController.isStoreActionInFlight == false
    }

    private func selectVibe(_ style: StyleRewriteStyle) {
        guard style != .none else {
            settingsStore.selectedVibe = .none
            return
        }

        guard isVibesAIInstalled else {
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

    private func handleKeyVoxVibesCardAction() {
        appHaptics.light()

        switch keyVoxVibesMatrix.cardAction {
        case .openUnlockScene:
            keyVoxVibesPurchaseController.presentUnlockSheet()
        case .openSceneCRecovery, .openUnlockedModelRecovery:
            keyVoxVibesPurchaseController.presentModelRecoverySheet()
        case .openUnlockFlow:
            keyVoxVibesPurchaseController.presentUnlockSheet()
        case .openIntroFlow:
            keyVoxVibesPurchaseController.presentIntroSheet()
        case .openVibeSelector:
            break
        }
    }

    private func handleVibesHelpAction() {
        appHaptics.light()
        keyVoxVibesPurchaseController.presentHelpSheet()
    }

    private var keyVoxVibesMatrix: KeyVoxVibesAccessMatrix {
        KeyVoxVibesAccessMatrix.resolve(
            accessState: KeyVoxVibesAccessMatrix.accessState(
                isVibesUnlocked: keyVoxVibesPurchaseController.isVibesUnlocked,
                hasTrialStarted: keyVoxVibesPurchaseController.hasTrialStarted,
                isTrialActive: keyVoxVibesPurchaseController.isTrialActive
            ),
            modelState: KeyVoxVibesAccessMatrix.modelState(isVibesAIInstalled: isVibesAIInstalled),
            selectedVibe: settingsStore.selectedVibe
        )
    }
}
