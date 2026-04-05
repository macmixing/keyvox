import SwiftUI

struct ShareFeedbackView: View {
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            Color(
                .sRGB,
                red: 26.0 / 255.0,
                green: 23.0 / 255.0,
                blue: 64.0 / 255.0,
                opacity: 1
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("keyvox-circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .opacity(isVisible ? 1 : 0)
                
                VStack(spacing: 8) {
                    Text("Opening KeyVox")
                        .font(appFont(22, variant: .medium))
                        .foregroundStyle(.white)
                    
                    Text("Preparing to speak text")
                        .font(appFont(16, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(isVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
    
    private func appFont(_ size: CGFloat, variant: AppTypographyVariant = .medium) -> Font {
        let fontName: String
        switch variant {
        case .medium:
            fontName = "Kanit-Medium"
        case .light:
            fontName = "Kanit-Light"
        }
        
        if UIFont(name: fontName, size: size) != nil {
            return .custom(fontName, size: size)
        }
        
        return .system(size: size, weight: variant == .medium ? .regular : .light)
    }
}

enum AppTypographyVariant {
    case medium
    case light
}

#Preview {
    ShareFeedbackView()
}
