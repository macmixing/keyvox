import Combine
import SwiftUI

@MainActor
final class PasteFailureRecoveryOverlayModel: ObservableObject {
    @Published var progress: Double
    let onDismiss: () -> Void

    init(progress: Double, onDismiss: @escaping () -> Void) {
        self.progress = progress
        self.onDismiss = onDismiss
    }
}

struct PasteFailureRecoveryOverlayView: View {
    @ObservedObject var model: PasteFailureRecoveryOverlayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow)

                Text("Paste Failed!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer(minLength: 0)

                Button(action: model.onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            Text("Click a textbox and use ⌘ Cmd + V to paste")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.12))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.indigo)
                        .frame(width: max(0, geometry.size.width * max(0, min(1, model.progress))))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .frame(width: 320)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
