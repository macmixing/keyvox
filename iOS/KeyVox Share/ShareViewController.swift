//
//  ShareViewController.swift
//  KeyVox Share
//
//  Created by Dom Esposito on 4/3/26.
//

import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    private lazy var appLauncher = KeyVoxShareAppLauncher(responderProvider: { [weak self] in
        self
    })
    private var hasStartedProcessing = false
    private var feedbackHostingController: UIHostingController<ShareFeedbackView>?

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
            showFeedback()
            
            let extractedText = await KeyVoxShareContentExtractor.extractText(from: extensionContext)
            let sharedText = extractedText

            if let sharedText, sharedText.isEmpty == false {
                NSLog("[KeyVoxShare] Extracted share text length=%d", sharedText.count)
                KeyVoxShareBridge.writeTTSRequest(sharedText)
                
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                appLauncher.open(KeyVoxShareBridge.startTTSURL)
                
                try? await Task.sleep(nanoseconds: 200_000_000)
            } else {
                NSLog("[KeyVoxShare] No share text could be extracted.")
            }

            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func showFeedback() {
        let feedbackView = ShareFeedbackView()
        let hostingController = UIHostingController(rootView: feedbackView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        feedbackHostingController = hostingController
    }
}
