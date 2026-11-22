import Foundation
import WebKit

/// Serves the microphone capture page from the keyboard's bundle under its own scheme, which
/// gives the page the secure context microphone capture needs.
final class KeyboardMicrophoneCaptureSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "keyvox-capture"
    static let pageURL = URL(string: "\(scheme)://keyboard/MicrophoneCapture.html")!

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let fileURL = Bundle.main.url(
                  forResource: url.deletingPathExtension().lastPathComponent,
                  withExtension: url.pathExtension
              ),
              let data = try? Data(contentsOf: fileURL),
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: [
                      "Content-Type": "text/html; charset=utf-8",
                      "Content-Length": "\(data.count)",
                      "Cache-Control": "no-store",
                      "Cross-Origin-Opener-Policy": "same-origin",
                      "Cross-Origin-Embedder-Policy": "require-corp",
                      "Cross-Origin-Resource-Policy": "same-origin",
                  ]
              ) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
