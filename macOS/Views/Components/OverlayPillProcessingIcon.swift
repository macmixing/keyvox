import SwiftUI

struct OverlayPillProcessingIcon<Icon: View>: View {
    let isProcessing: Bool
    let foregroundColor: Color
    let idleScale: CGFloat
    let icon: Icon

    @State private var isPulsing = false

    init(
        isProcessing: Bool,
        foregroundColor: Color,
        idleScale: CGFloat,
        @ViewBuilder icon: () -> Icon
    ) {
        self.isProcessing = isProcessing
        self.foregroundColor = foregroundColor
        self.idleScale = idleScale
        self.icon = icon()
    }

    var body: some View {
        ZStack {
            icon
                .foregroundStyle(Color.yellow.opacity(isProcessing ? (isPulsing ? 0.92 : 0.48) : 0))
                .scaleEffect(isProcessing && isPulsing ? 1.24 : 1.08)
                .blur(radius: isProcessing ? 4 : 0)
                .accessibilityHidden(true)

            icon
                .foregroundStyle(foregroundColor)
                .scaleEffect(isProcessing && isPulsing ? 1.08 : idleScale)
        }
        .onAppear(perform: updateProcessingAnimation)
        .onChange(of: isProcessing) { _ in
            updateProcessingAnimation()
        }
    }

    private func updateProcessingAnimation() {
        guard isProcessing else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
