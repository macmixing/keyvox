import SwiftUI

struct OnboardingKeyboardTourSceneAView: View {
    private enum MenuFrame: CaseIterable {
        case one
        case two
        case three

        var assetName: String {
            switch self {
            case .one:
                return "keybaord-menu1"
            case .two:
                return "keybaord-menu2"
            case .three:
                return "keybaord-menu3"
            }
        }
    }

    private enum Metrics {
        static let guidanceBottomOffset: CGFloat = 128
        static let arrowBottomOffset: CGFloat = 122
        static let menuArtworkWidth: CGFloat = 160
        static let menuArtworkOffset: CGFloat = 30
    }

    @State private var isArrowFloating = false
    @State private var currentMenuFrame: MenuFrame = .one
    @State private var isMenuVisible = false
    @State private var menuSequenceTask: Task<Void, Never>?
    @State private var menuRevealTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            menuSequenceView
                .offset(y: Metrics.menuArtworkOffset)
                .opacity(isMenuVisible ? 1 : 0)

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
            startMenuReveal()
            startMenuSequence()
        }
        .onDisappear {
            isArrowFloating = false
            stopMenuReveal()
            stopMenuSequence()
        }
    }

    private var menuSequenceView: some View {
        ZStack {
            Image("keybaord-menu")
                .resizable()
                .scaledToFit()
                .frame(width: Metrics.menuArtworkWidth)
                .fixedSize()

            ForEach(MenuFrame.allCases, id: \.assetName) { frame in
                Image(frame.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Metrics.menuArtworkWidth)
                    .fixedSize()
                    .opacity(currentMenuFrame == frame ? 1 : 0)
            }
        }
        .fixedSize()
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

    private func startMenuSequence() {
        stopMenuSequence()
        currentMenuFrame = .one

        menuSequenceTask = Task { @MainActor in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1.5))
                guard Task.isCancelled == false else { return }

                withAnimation(.easeInOut(duration: 0.36)) {
                    currentMenuFrame = .two
                }

                try? await Task.sleep(for: .seconds(1.5))
                guard Task.isCancelled == false else { return }

                withAnimation(.easeInOut(duration: 0.36)) {
                    currentMenuFrame = .three
                }

                try? await Task.sleep(for: .seconds(3.0))
                guard Task.isCancelled == false else { return }

                withAnimation(.easeInOut(duration: 0.36)) {
                    currentMenuFrame = .one
                }
            }
        }
    }

    private func stopMenuSequence() {
        menuSequenceTask?.cancel()
        menuSequenceTask = nil
    }

    private func startMenuReveal() {
        stopMenuReveal()
        isMenuVisible = false

        menuRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                isMenuVisible = true
            }
        }
    }

    private func stopMenuReveal() {
        menuRevealTask?.cancel()
        menuRevealTask = nil
        isMenuVisible = false
    }
}
