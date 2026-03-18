import SwiftUI
import AppKit

enum AppTypography {
    enum Variant {
        case medium
        case light

        fileprivate var candidateFontNames: [String] {
            switch self {
            case .medium:
                return [
                    "Kanit-Medium",
                    "Kanit Medium",
                ]
            case .light:
                return [
                    "Kanit-Light",
                    "Kanit Light",
                ]
            }
        }

        fileprivate var fallbackWeight: Font.Weight {
            switch self {
            case .medium:
                return .regular
            case .light:
                return .light
            }
        }
    }

    static func resolvedFontName(for size: CGFloat, variant: Variant) -> String? {
        for name in variant.candidateFontNames where NSFont(name: name, size: size) != nil {
            return name
        }

        return nil
    }
}

extension Font {
    static func appFont(_ size: CGFloat, variant: AppTypography.Variant = .medium) -> Font {
        if let name = AppTypography.resolvedFontName(for: size, variant: variant) {
            return .custom(name, size: size)
        }

        return .system(size: size, weight: variant.fallbackWeight)
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
                        .fill(MacAppTheme.accent)
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .shadow(color: MacAppTheme.accent.opacity(0.5), radius: 3)
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
                        .foregroundColor(MacAppTheme.accent)
                }
            }
        }
    }
}
