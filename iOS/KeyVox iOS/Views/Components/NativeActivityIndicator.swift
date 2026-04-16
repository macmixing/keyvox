import SwiftUI
import UIKit

struct NativeActivityIndicator: UIViewRepresentable {
    let color: UIColor
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.color = color
        view.hidesWhenStopped = false
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.color = color

        if !uiView.isAnimating {
            uiView.startAnimating()
        }
    }
}
