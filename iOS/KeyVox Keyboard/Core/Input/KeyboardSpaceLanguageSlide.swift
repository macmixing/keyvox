import CoreGraphics

/// Whether a finger that lifted off the space bar slid sideways to switch the typing language: it
/// went at least `minimumTravel` points, more sideways than up or down, and the cursor trackpad never
/// took it. The trackpad starts only on a finger held still, so a slide is one that started moving
/// before that hold; a finger held into the trackpad moves the cursor and never switches.
nonisolated enum KeyboardSpaceLanguageSlide {
    /// How far sideways the finger must go, well past the movement that keeps the trackpad's hold
    /// from starting.
    static let minimumTravel: CGFloat = 30

    /// One place forward for a slide to the right, one back for a slide to the left, or nil when the
    /// finger did not slide.
    static func offset(from start: CGPoint, to end: CGPoint, trackpadWasActive: Bool) -> Int? {
        guard trackpadWasActive == false else { return nil }
        let horizontal = end.x - start.x
        let vertical = end.y - start.y
        guard abs(horizontal) >= minimumTravel, abs(horizontal) > abs(vertical) else { return nil }
        return horizontal > 0 ? 1 : -1
    }
}
