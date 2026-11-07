import UIKit
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyboardViewControllerTests {
    @Test func disappearanceLeavesTheConstrainedViewsMountedAndStopsIPC() throws {
        let controller = KeyboardViewController(nibName: nil, bundle: nil)
        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        let root = try #require(controller.rootContainerView)
        let overlay = try #require(controller.popupOverlayView)

        #expect(controller.debugIPCObserverRegistrationActive)

        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)

        #expect(root.superview === controller.view)
        #expect(overlay.superview === controller.view)
        #expect(root.isHidden)
        #expect(overlay.isHidden)
        #expect(controller.debugIPCObserverRegistrationActive == false)
        #expect(controller.debugHasHostLifecycleObservers)
    }

    @Test func reappearingShowsAndRebindsTheSameViews() throws {
        let controller = KeyboardViewController(nibName: nil, bundle: nil)
        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        let root = try #require(controller.rootContainerView)

        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)
        controller.viewWillAppear(false)

        #expect(controller.rootContainerView === root)
        #expect(root.isHidden == false)
        #expect(controller.debugIPCObserverRegistrationActive)
    }

    @Test func fullAccessInstructionsCloseAcrossPresentations() throws {
        let controller = KeyboardViewController(nibName: nil, bundle: nil)
        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        controller.setFullAccessInstructionsPresented(true)
        let instructions = try #require(controller.fullAccessView)

        #expect(instructions.isHidden == false)

        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)
        controller.viewWillAppear(false)

        #expect(instructions.superview === controller.view)
        #expect(instructions.isHidden)
        #expect(controller.rootContainerView?.isHidden == false)
    }

    @Test func hostBackgroundingKeepsThePresentationBound() throws {
        let controller = KeyboardViewController(nibName: nil, bundle: nil)
        controller.loadViewIfNeeded()
        controller.viewWillAppear(false)
        let root = try #require(controller.rootContainerView)

        NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostWillResignActive, object: nil)
        controller.viewWillDisappear(false)
        controller.viewDidDisappear(false)
        NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)

        #expect(controller.rootContainerView === root)
        #expect(root.isHidden == false)
        #expect(controller.debugIPCObserverRegistrationActive)
        #expect(controller.debugHasHostLifecycleObservers)
    }

    @Test func deallocationLeavesRemovalToTheHostViewOwner() throws {
        weak var releasedController: KeyboardViewController?
        let (hostView, root) = try autoreleasepool {
            let controller = KeyboardViewController(nibName: nil, bundle: nil)
            controller.loadViewIfNeeded()
            controller.viewWillAppear(false)
            releasedController = controller
            let hostView = try #require(controller.view)
            let root = try #require(controller.rootContainerView)
            // Model UIKit retaining the old input view after disconnecting the controller.
            controller.view = UIView()
            return (hostView, root)
        }

        #expect(releasedController == nil)
        #expect(root.superview === hostView)
    }
}
