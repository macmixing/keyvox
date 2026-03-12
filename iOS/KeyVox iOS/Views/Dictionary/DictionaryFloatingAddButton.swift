import SwiftUI

struct DictionaryFloatingAddButton: View {
    let action: () -> Void
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundStyle(iOSAppTheme.accent)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .systemYellow), lineWidth: 2)
                        )
                        .shadow(color: iOSAppTheme.accent.opacity(0.28), radius: 20, y: 10)
                        .shadow(color: Color.black.opacity(0.36), radius: 14, y: 8)
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
