import SwiftUI

/// Gives a menu picker its usual width, widened only when the selected title needs more room,
/// so longer translations show in full while shorter titles keep the original layout.
struct MenuPickerWidth: ViewModifier {
    let selectedTitle: String
    let minimumWidth: CGFloat

    func body(content: Content) -> some View {
        Picker("", selection: .constant(0)) {
            Text(selectedTitle).tag(0)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .frame(minWidth: minimumWidth)
        .fixedSize()
        .hidden()
        .accessibilityHidden(true)
        .overlay {
            content
        }
    }
}

extension View {
    func menuPickerWidth(fitting selectedTitle: String, minimumWidth: CGFloat) -> some View {
        modifier(MenuPickerWidth(selectedTitle: selectedTitle, minimumWidth: minimumWidth))
    }
}
