import UIKit

/// The views keyboard controllers mount in their input views, by the controller that mounted
/// them. UIKit can hold on to a dismissed keyboard's input view after releasing its controller,
/// which keeps that controller's views mounted, and in memory, for as long as the keyboard runs;
/// every appearance would leave another set behind. Removing a set once its controller is gone and
/// it is off screen frees it without touching a view UIKit may still be laying out.
enum KeyboardPresentationViewRegistry {
    private struct Entry {
        weak var owner: UIInputViewController?
        weak var view: UIView?
    }

    private static var entries: [Entry] = []

    /// Records `view` as mounted by `owner`.
    static func register(_ view: UIView, mountedBy owner: UIInputViewController) {
        entries.append(Entry(owner: owner, view: view))
    }

    /// Removes the views whose controller has been released and that are off screen.
    static func removeViewsOfReleasedControllers() {
        for entry in entries where entry.owner == nil {
            guard let view = entry.view, view.window == nil else { continue }
            view.removeFromSuperview()
        }
        entries.removeAll { $0.view == nil || ($0.owner == nil && $0.view?.superview == nil) }
    }
}
