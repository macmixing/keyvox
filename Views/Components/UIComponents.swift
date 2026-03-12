import SwiftUI
import AppKit

enum AppTypography {
    static let primaryUIFontName = "Kanit Medium"
}

extension Font {
    static func appFont(_ size: CGFloat) -> Font {
        .custom(AppTypography.primaryUIFontName, size: size)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
struct KeyVoxProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                
                if let progress = configuration.fractionCompleted {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.indigo)
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .shadow(color: .indigo.opacity(0.5), radius: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
        }
    }
}

struct ModelDownloadProgress: View {
    let progress: Double
    var showLabel: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(KeyVoxProgressStyle())
                .frame(height: 6)
            
            if showLabel {
                HStack {
                    Text("Preparing AI Assets...")
                        .font(.appFont(10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.appFont(11))
                        .foregroundColor(.indigo)
                }
            }
        }
    }
}
