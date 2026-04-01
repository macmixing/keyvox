import UIKit
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyboardViewControllerTests {
    @Test func viewDisappearanceTearsDownPresentationTreeButKeepsHostLifecycleObservers() {
        KeyboardViewController.resetPresentationLifecycleDiagnostics()
        let controller = KeyboardViewController(nibName: nil, bundle: nil)

        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)

        #expect(controller.debugHasPresentationViewTree)
        #expect(controller.debugIPCObserverRegistrationActive)
        #expect(controller.debugHasHostLifecycleObservers)
        #expect(KeyboardViewController.debugCreatedPresentationViewTreeCount == 1)

        controller.viewDidDisappear(false)

        #expect(controller.debugHasPresentationViewTree == false)
        #expect(controller.debugIPCObserverRegistrationActive == false)
        #expect(controller.debugHasHostLifecycleObservers)
        #expect(KeyboardViewController.debugDestroyedPresentationViewTreeCount == 1)
    }

    @Test func reappearingRebuildsExactlyOneFreshPresentationTree() {
        KeyboardViewController.resetPresentationLifecycleDiagnostics()
        let controller = KeyboardViewController(nibName: nil, bundle: nil)

        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        let firstRootViewIdentifier = controller.debugRootViewIdentifier

        controller.viewDidDisappear(false)
        controller.viewWillAppear(false)

        #expect(controller.debugHasPresentationViewTree)
        #expect(controller.debugRootViewIdentifier != nil)
        #expect(controller.debugRootViewIdentifier != firstRootViewIdentifier)
        #expect(KeyboardViewController.debugCreatedPresentationViewTreeCount == 2)
        #expect(KeyboardViewController.debugDestroyedPresentationViewTreeCount == 1)
    }

    @Test func fullAccessInstructionsDoNotPersistAcrossPresentationTeardown() {
        KeyboardViewController.resetPresentationLifecycleDiagnostics()
        let controller = KeyboardViewController(nibName: nil, bundle: nil)

        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        controller.debugPresentFullAccessInstructionsForTesting()

        #expect(controller.debugFullAccessViewIdentifier != nil)

        controller.viewDidDisappear(false)
        controller.viewWillAppear(false)

        #expect(controller.debugFullAccessViewIdentifier == nil)
    }

    @Test func hostBackgroundingDoesNotTearDownActivePresentationTree() {
        KeyboardViewController.resetPresentationLifecycleDiagnostics()
        let controller = KeyboardViewController(nibName: nil, bundle: nil)

        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        let firstRootViewIdentifier = controller.debugRootViewIdentifier

        NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostWillResignActive, object: nil)
        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)
        NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)

        #expect(controller.debugHasPresentationViewTree)
        #expect(controller.debugRootViewIdentifier == firstRootViewIdentifier)
        #expect(controller.debugHasHostLifecycleObservers)
        #expect(KeyboardViewController.debugCreatedPresentationViewTreeCount == 1)
        #expect(KeyboardViewController.debugDestroyedPresentationViewTreeCount == 0)
    }
}
