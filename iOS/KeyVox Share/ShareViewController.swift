//
//  ShareViewController.swift
//  KeyVox Share
//
//  Created by Dom Esposito on 4/3/26.
//

import UIKit

final class ShareViewController: UIViewController {
    private lazy var appLauncher = KeyVoxShareAppLauncher(responderProvider: { [weak self] in
        self
    })
    private var hasStartedProcessing = false

    override func loadView() {
        self.view = UIView()
        self.view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        beginProcessingIfNeeded()
    }

    private func beginProcessingIfNeeded() {
        guard hasStartedProcessing == false else { return }
        hasStartedProcessing = true

        Task { @MainActor in
            NSLog("[KeyVoxShare] Beginning share processing.")
            let extractedText = await KeyVoxShareContentExtractor.extractText(from: extensionContext)
            let sharedText = extractedText

            if let sharedText, sharedText.isEmpty == false {
                NSLog("[KeyVoxShare] Extracted share text length=%d", sharedText.count)
                KeyVoxShareBridge.writeTTSRequest(sharedText)
                appLauncher.open(KeyVoxShareBridge.startTTSURL)
            } else {
                NSLog("[KeyVoxShare] No share text could be extracted.")
            }

            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
