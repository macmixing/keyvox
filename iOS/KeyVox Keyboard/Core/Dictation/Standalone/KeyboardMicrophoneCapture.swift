import UIKit
import WebKit

/// Records the microphone from inside the keyboard. A keyboard cannot open the microphone
/// itself, but a web view it shows can, so a web view with nothing to see captures the audio
/// and hands it over as mono Float32 samples at the microphone's sample rate.
@MainActor
final class KeyboardMicrophoneCapture: NSObject {
    private enum MessageType: String {
        case ready
        case started
        case audio
        case stopped
        case failed
    }

    private static let messageHandlerName = "capture"

    var onStarted: (() -> Void)?
    var onAudio: ((_ samples: Data, _ sampleRate: Double) -> Void)?
    var onStopped: (() -> Void)?
    var onFailure: (() -> Void)?

    private let mount: (UIView) -> Void
    private var webView: WKWebView?
    private var isPageReady = false
    private var isLoadingPage = false
    private var startsWhenPageIsReady = false

    /// - Parameter mount: Adds the web view to the keyboard's view tree, where it must live to
    ///   capture.
    init(mount: @escaping (UIView) -> Void) {
        self.mount = mount
    }

    func start() {
        guard isPageReady else {
            startsWhenPageIsReady = true
            loadPageIfNeeded()
            return
        }
        evaluate("startCapture()")
    }

    func stop() {
        startsWhenPageIsReady = false
        guard isPageReady else {
            onStopped?()
            return
        }
        evaluate("stopCapture()")
    }

    /// Stops any capture without reporting back.
    func cancel() {
        startsWhenPageIsReady = false
        guard isPageReady else { return }
        webView?.evaluateJavaScript("release(); 0")
    }

    private func loadPageIfNeeded() {
        guard !isLoadingPage else { return }
        isLoadingPage = true
        (webView ?? makeWebView()).load(URLRequest(url: KeyboardMicrophoneCaptureSchemeHandler.pageURL))
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.setURLSchemeHandler(
            KeyboardMicrophoneCaptureSchemeHandler(),
            forURLScheme: KeyboardMicrophoneCaptureSchemeHandler.scheme
        )
        configuration.userContentController.add(
            KeyboardMicrophoneCaptureMessageRelay(self),
            name: Self.messageHandlerName
        )
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isUserInteractionEnabled = false
        webView.isAccessibilityElement = false
        webView.alpha = 0.02
        self.webView = webView
        mount(webView)
        return webView
    }

    private func evaluate(_ call: String) {
        webView?.evaluateJavaScript("\(call); 0") { [weak self] _, error in
            guard error != nil else { return }
            self?.fail()
        }
    }

    private func fail() {
        isLoadingPage = false
        startsWhenPageIsReady = false
        onFailure?()
    }

    fileprivate func handleMessage(_ body: Any) {
        guard let message = body as? [String: Any],
              let rawType = message["type"] as? String,
              let type = MessageType(rawValue: rawType) else {
            return
        }

        switch type {
        case .ready:
            isPageReady = true
            isLoadingPage = false
            if startsWhenPageIsReady {
                startsWhenPageIsReady = false
                evaluate("startCapture()")
            }
        case .started:
            onStarted?()
        case .audio:
            guard let encodedSamples = message["samples"] as? String,
                  let samples = Data(base64Encoded: encodedSamples),
                  let sampleRate = message["sampleRate"] as? Double else {
                return
            }
            onAudio?(samples, sampleRate)
        case .stopped:
            onStopped?()
        case .failed:
            fail()
        }
    }
}

extension KeyboardMicrophoneCapture: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        fail()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        fail()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isPageReady = false
        fail()
    }
}

extension KeyboardMicrophoneCapture: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
        decisionHandler(type == .microphone ? .grant : .deny)
    }
}

/// Keeps the web view's message handler from retaining the capture that owns the web view.
private final class KeyboardMicrophoneCaptureMessageRelay: NSObject, WKScriptMessageHandler {
    private weak var capture: KeyboardMicrophoneCapture?

    init(_ capture: KeyboardMicrophoneCapture) {
        self.capture = capture
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        capture?.handleMessage(message.body)
    }
}
