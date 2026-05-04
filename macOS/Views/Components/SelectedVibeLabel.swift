import SwiftUI

struct SelectedVibeLabel: View {
    static let panelSize = CGSize(width: 96, height: 18)

    let title: String

    @State private var labelScale: CGFloat = 0.12
    @State private var labelOpacity: Double = 0
    @State private var popWorkItem: DispatchWorkItem?
    @State private var settleWorkItem: DispatchWorkItem?

    var body: some View {
        Text(title)
            .font(.appFont(11))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .shadow(color: .black.opacity(0.95), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.8), radius: 0.5, x: 0, y: 0)
            .opacity(labelOpacity)
            .scaleEffect(labelScale)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .onAppear(perform: animateEntrance)
            .onDisappear {
                popWorkItem?.cancel()
                popWorkItem = nil
                settleWorkItem?.cancel()
                settleWorkItem = nil
            }
    }

    private func animateEntrance() {
        popWorkItem?.cancel()
        popWorkItem = nil
        settleWorkItem?.cancel()
        settleWorkItem = nil

        labelScale = 0.12
        labelOpacity = 0
        withAnimation(.easeOut(duration: 0.1)) {
            labelScale = 0.92
            labelOpacity = 1
        }

        let pop = DispatchWorkItem {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.04)) {
                labelScale = 1.06
            }
        }
        popWorkItem = pop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: pop)

        let settle = DispatchWorkItem {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8, blendDuration: 0.06)) {
                labelScale = 1.0
            }
        }
        settleWorkItem = settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: settle)
    }
}
