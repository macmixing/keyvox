import SwiftUI

struct KeyboardMenuSequence: View {
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

    let width: CGFloat

    @State private var currentMenuFrame: MenuFrame = .one
    @State private var isVisible = false
    @State private var menuSequenceTask: Task<Void, Never>?
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Image("keybaord-menu")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .fixedSize()

            ForEach(MenuFrame.allCases, id: \.assetName) { frame in
                Image(frame.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .fixedSize()
                    .opacity(currentMenuFrame == frame ? 1 : 0)
            }
        }
        .fixedSize()
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            startReveal()
            startSequence()
        }
        .onDisappear {
            stopReveal()
            stopSequence()
        }
    }

    private func startSequence() {
        stopSequence()
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

    private func stopSequence() {
        menuSequenceTask?.cancel()
        menuSequenceTask = nil
    }

    private func startReveal() {
        stopReveal()
        isVisible = false

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
        }
    }

    private func stopReveal() {
        revealTask?.cancel()
        revealTask = nil
        isVisible = false
    }
}
