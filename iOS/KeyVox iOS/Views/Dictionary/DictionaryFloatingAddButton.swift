import SwiftUI

struct DictionaryFloatingAddButton: View {
    let action: () -> Void
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    iOSAppTheme.accent.opacity(0.98),
                                    iOSAppTheme.accent.opacity(0.82),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: iOSAppTheme.accent.opacity(0.32), radius: 18, y: 10)
                        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.88 : 1)
        .opacity(isPressed ? 0.72 : 1)
        .animation(.easeOut(duration: 0.16), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .accessibilityLabel("Add Word")
    }
}
