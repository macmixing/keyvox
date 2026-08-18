import KeyVoxCore
import SwiftUI

struct OnboardingView: View {
    static let preferredWindowSize = CGSize(width: 560, height: 560)

    private enum Route: Equatable {
        case welcome
        case language
        case setup
    }

    @State private var route: Route = .welcome
    @State private var selectedLanguage: DictationLanguage?

    let onComplete: () -> Void
    let openSettings: () -> Void
    var beginMicrophoneAuthorization: () -> Void = {}
    var beginAccessibilityAuthorization: () -> Void = {}
    var endAccessibilityAuthorization: () -> Void = {}
    var onPreferredHeightChange: (CGFloat) -> Void = { _ in }

    var body: some View {
        ZStack {
            MacAppTheme.screenBackground

            switch route {
            case .welcome:
                OnboardingWelcomeScreen {
                    route = .language
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.985)),
                    removal: .scale(scale: 1.015)
                ))

            case .language:
                OnboardingLanguageScreen(selection: $selectedLanguage) { language in
                    AppSettingsStore.shared.whisperDictationLanguage = language
                    route = .setup
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .scale(scale: 1.015)
                ))

            case .setup:
                OnboardingSetupScreen(
                    onBack: {
                        route = .language
                    },
                    onComplete: onComplete,
                    openSettings: openSettings,
                    beginMicrophoneAuthorization: beginMicrophoneAuthorization,
                    beginAccessibilityAuthorization: beginAccessibilityAuthorization,
                    endAccessibilityAuthorization: endAccessibilityAuthorization,
                    onPreferredHeightChange: onPreferredHeightChange
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .scale(scale: 1.015)
                ))
            }
        }
        .frame(width: Self.preferredWindowSize.width)
        .frame(minHeight: Self.preferredWindowSize.height)
        .background(MacAppTheme.screenBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.easeInOut(duration: 0.34), value: route)
        .onAppear {
            onPreferredHeightChange(Self.preferredWindowSize.height)
        }
        .onChange(of: route) { _ in
            onPreferredHeightChange(Self.preferredWindowSize.height)
        }
    }
}
