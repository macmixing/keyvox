import Cocoa

struct PasteMenuFallbackExecutionResult {
    let didMenuFallbackInsert: Bool
    let menuAttempt: PasteMenuFallbackAttemptResult?
    let suppressFirstWarmupFailureWarning: Bool
}

protocol PasteMenuFallbackCoordinating {
    func executeMenuFallback(
        insertionText: String,
        didAccessibilityInsertText: Bool,
        targetAppIdentity: PasteAppIdentity?,
        menuFallbackExecutor: PasteMenuFallbackExecuting,
        shouldTrustMenuSuccessWithoutAXVerification: () -> Bool,
        setClipboardStringOnMainThread: (String) -> Void,
        typeLeadingSpacesOnMainThread: (Int) -> Bool
    ) -> PasteMenuFallbackExecutionResult
}

final class PasteMenuFallbackCoordinator {
    private var seenMenuSuccessAttemptProcessKeys: Set<String> = []
    private var warmupSuppressionEligibilityByProcessKey: [String: Bool] = [:]
    private let electronFrameworkDetector: (pid_t) -> Bool

    init(
        electronFrameworkDetector: ((pid_t) -> Bool)? = nil
    ) {
        if let electronFrameworkDetector {
            self.electronFrameworkDetector = electronFrameworkDetector
        } else {
            self.electronFrameworkDetector = { processID in
                PasteMenuFallbackCoordinator.hasElectronFramework(processID: processID)
            }
        }
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    func executeMenuFallback(
        insertionText: String,
        didAccessibilityInsertText: Bool,
        targetAppIdentity: PasteAppIdentity?,
        menuFallbackExecutor: PasteMenuFallbackExecuting,
        shouldTrustMenuSuccessWithoutAXVerification: () -> Bool,
        setClipboardStringOnMainThread: (String) -> Void,
        typeLeadingSpacesOnMainThread: (Int) -> Bool
    ) -> PasteMenuFallbackExecutionResult {
        #if DEBUG
        print("Accessibility injection failed/skipped. Triggering Menu Bar Paste...")
        #endif

        var didMenuFallbackInsert = false
        var menuAttempt: PasteMenuFallbackAttemptResult?
        var isFirstMenuSuccessAttemptForProcess = false

        var textForMenuPaste = insertionText
        var didTypeLeadingSpaces = false
        let verificationContext = menuFallbackExecutor.captureVerificationContext()
        let initialUndoState = (verificationContext == nil)
            ? menuFallbackExecutor.captureUndoStateOnMainThread()
            : nil

        // Some apps normalize leading spaces on paste. If AX injection fully failed,
        // type leading spaces as key events, then paste the remaining text.
        if !didAccessibilityInsertText {
            let transport = menuFallbackTransport(for: insertionText)
            textForMenuPaste = transport.textToPaste

            if transport.leadingSpacesToType > 0 {
                didTypeLeadingSpaces = typeLeadingSpacesOnMainThread(transport.leadingSpacesToType)
            }
        }

        if textForMenuPaste != insertionText {
            setClipboardStringOnMainThread(textForMenuPaste)
        }

        if textForMenuPaste.isEmpty {
            didMenuFallbackInsert = Self.didMenuFallbackInsertForEmptyClipboardPayload(
                didTypeLeadingSpaces: didTypeLeadingSpaces
            )
        } else {
            let liveValueChangeSession = menuFallbackExecutor.startLiveValueChangeVerificationSession(
                processID: targetAppIdentity?.pid
            )
            defer {
                menuFallbackExecutor.finishLiveValueChangeVerificationSession(liveValueChangeSession)
            }

            let menuAttemptResult = menuFallbackExecutor.pasteViaMenuBarOnMainThread()
            menuAttempt = menuAttemptResult
            var trustWithoutAXVerification = false
            var verificationPassed = false

            if case .actionSucceeded = menuAttemptResult,
               shouldAllowFirstMenuSuccessWarmupSuppression(for: targetAppIdentity) {
                isFirstMenuSuccessAttemptForProcess = !hasSeenMenuSuccessAttempt(for: targetAppIdentity)
                markMenuSuccessAttemptSeen(for: targetAppIdentity)
            }

            switch menuAttemptResult {
            case .unavailable:
                break
            case .actionSucceeded:
                trustWithoutAXVerification = shouldTrustMenuSuccessWithoutAXVerification()
                if !trustWithoutAXVerification {
                    if verificationContext != nil {
                        // Even when AXPress reports success, verify resulting AX state when possible
                        // so we can catch no-op "successful" actions in apps like browser-based editors.
                        verificationPassed = menuFallbackExecutor.verifyInsertion(using: verificationContext)
                    } else {
                        verificationPassed = menuFallbackExecutor.verifyInsertionWithoutAXContextOnMainThread(
                            initialUndoState: initialUndoState
                        )
                    }
                    if !verificationPassed {
                        verificationPassed = menuFallbackExecutor.verifyInsertionUsingLiveValueChangeSession(
                            liveValueChangeSession
                        )
                    }
                }
            case .actionErrored:
                if verificationContext != nil {
                    verificationPassed = menuFallbackExecutor.verifyInsertion(using: verificationContext)
                } else {
                    verificationPassed = menuFallbackExecutor.verifyInsertionWithoutAXContextOnMainThread(
                        initialUndoState: initialUndoState
                    )
                }
            }

            didMenuFallbackInsert = Self.didMenuFallbackInsertForMenuAttempt(
                attempt: menuAttemptResult,
                trustMenuSuccessWithoutAXVerification: trustWithoutAXVerification,
                verificationPassed: verificationPassed
            )
        }

        let suppressFirstWarmupFailureWarning = Self.shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
            attempt: menuAttempt,
            didAccessibilityInsertText: didAccessibilityInsertText,
            didMenuFallbackInsert: didMenuFallbackInsert,
            isFirstMenuSuccessAttemptForProcess: isFirstMenuSuccessAttemptForProcess
        )

        return PasteMenuFallbackExecutionResult(
            didMenuFallbackInsert: didMenuFallbackInsert,
            menuAttempt: menuAttempt,
            suppressFirstWarmupFailureWarning: suppressFirstWarmupFailureWarning
        )
    }

    static func didMenuFallbackInsertForEmptyClipboardPayload(
        didTypeLeadingSpaces: Bool
    ) -> Bool {
        didTypeLeadingSpaces
    }

    static func didMenuFallbackInsertForMenuAttempt(
        attempt: PasteMenuFallbackAttemptResult,
        trustMenuSuccessWithoutAXVerification: Bool,
        verificationPassed: Bool
    ) -> Bool {
        switch attempt {
        case .unavailable:
            return false
        case .actionSucceeded:
            return trustMenuSuccessWithoutAXVerification || verificationPassed
        case .actionErrored:
            return verificationPassed
        }
    }

    static func shouldSuppressFailureWarningForFirstMenuSuccessAttempt(
        attempt: PasteMenuFallbackAttemptResult?,
        didAccessibilityInsertText: Bool,
        didMenuFallbackInsert: Bool,
        isFirstMenuSuccessAttemptForProcess: Bool
    ) -> Bool {
        guard isFirstMenuSuccessAttemptForProcess else { return false }
        guard !didAccessibilityInsertText else { return false }
        guard !didMenuFallbackInsert else { return false }
        if case .actionSucceeded = attempt {
            return true
        }
        return false
    }

    static func hasElectronFramework(processID: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: processID),
              let bundleURL = app.bundleURL else {
            return false
        }

        let electronFrameworkURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("Electron Framework.framework", isDirectory: true)

        if FileManager.default.fileExists(atPath: electronFrameworkURL.path) {
            return true
        }

        let frameworksDirectory = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Frameworks", isDirectory: true)

        guard let frameworkNames = try? FileManager.default.contentsOfDirectory(atPath: frameworksDirectory.path) else {
            return false
        }

        return containsElectronFramework(frameworkNames: frameworkNames)
    }

    static func containsElectronFramework(frameworkNames: [String]) -> Bool {
        frameworkNames.contains { name in
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "electron framework.framework" || normalized.contains("electron framework.framework")
        }
    }

    private func shouldAllowFirstMenuSuccessWarmupSuppression(for appIdentity: PasteAppIdentity?) -> Bool {
        guard let key = menuSuccessAttemptProcessKey(for: appIdentity),
              let appIdentity else {
            return false
        }

        if let cached = warmupSuppressionEligibilityByProcessKey[key] {
            return cached
        }

        let isEligible = electronFrameworkDetector(appIdentity.pid)
        warmupSuppressionEligibilityByProcessKey[key] = isEligible
        return isEligible
    }

    private func menuSuccessAttemptProcessKey(for appIdentity: PasteAppIdentity?) -> String? {
        guard let appIdentity else { return nil }
        let bundleID = appIdentity.bundleID ?? "<unknown>"
        return "\(bundleID)#\(appIdentity.pid)"
    }

    private func hasSeenMenuSuccessAttempt(for appIdentity: PasteAppIdentity?) -> Bool {
        guard let key = menuSuccessAttemptProcessKey(for: appIdentity) else { return false }
        return seenMenuSuccessAttemptProcessKeys.contains(key)
    }

    private func markMenuSuccessAttemptSeen(for appIdentity: PasteAppIdentity?) {
        guard let key = menuSuccessAttemptProcessKey(for: appIdentity) else { return }
        seenMenuSuccessAttemptProcessKeys.insert(key)
    }

    private func menuFallbackTransport(for text: String) -> PasteMenuFallbackTransport {
        let leadingSpaces = text.prefix { $0 == " " }.count
        guard leadingSpaces > 0 else {
            return PasteMenuFallbackTransport(leadingSpacesToType: 0, textToPaste: text)
        }

        let remainingText = String(text.dropFirst(leadingSpaces))
        return PasteMenuFallbackTransport(leadingSpacesToType: leadingSpaces, textToPaste: remainingText)
    }
}

extension PasteMenuFallbackCoordinator: PasteMenuFallbackCoordinating {}
