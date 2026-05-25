import SwiftUI
import UIKit

struct AppActivityShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct AppActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
