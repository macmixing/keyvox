//
//  ShareViewController.swift
//  KeyVox Share
//
//  Created by Dom Esposito on 4/3/26.
//

import UIKit
import Social

final class ShareViewController: SLComposeServiceViewController {
    private lazy var appLauncher = KeyVoxShareAppLauncher(responderProvider: { [weak self] in
        self
    })
    private var hasStartedProcessing = false

    override func isContentValid() -> Bool {
        return true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        beginProcessingIfNeeded()
    }

    override func didSelectPost() {
        beginProcessingIfNeeded()
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func beginProcessingIfNeeded() {
        guard hasStartedProcessing == false else { return }
        hasStartedProcessing = true

        Task { @MainActor in
            let extractedText = await KeyVoxShareContentExtractor.extractText(from: extensionContext)
            let fallbackText = contentText?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sharedText = extractedText?.isEmpty == false ? extractedText : fallbackText

            if let sharedText, sharedText.isEmpty == false {
                KeyVoxShareBridge.writeTTSRequest(sharedText)
                appLauncher.open(KeyVoxShareBridge.startTTSURL)
            }

            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
