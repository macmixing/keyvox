import SwiftUI

struct OnboardingKeyboardTourSceneAView: View {
    private enum Metrics {
        static let guidanceBottomOffset: CGFloat = 128
        static let arrowBottomOffset: CGFloat = 122
        static let menuArtworkWidth: CGFloat = 160
        static let menuArtworkOffset: CGFloat = 30
    }

    @State private var isArrowFloating = false

    var body: some View {
        ZStack {
            KeyboardMenuSequence(width: Metrics.menuArtworkWidth)
                .offset(y: Metrics.menuArtworkOffset)

            guidanceText
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
                .offset(y: Metrics.guidanceBottomOffset)

            floatingArrow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 20)
                .padding(.bottom, 6)
                .offset(y: Metrics.arrowBottomOffset + (isArrowFloating ? 10 : -2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isArrowFloating)
        .onAppear {
            isArrowFloating = true
        }
        .onDisappear {
            isArrowFloating = false
        }
    }

    private var guidanceText: some View {
        Text("Tap & hold the Globe, \n then select KeyVox.")
            .font(.appFont(17, variant: .light))
            .lineSpacing(1)
            .lineLimit(2)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }

    private var floatingArrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 44, weight: .heavy))
            .foregroundStyle(.yellow)
            .frame(width: 44, height: 44)
    }
}
