import CoreGraphics

/// Whether a finger that lifted off the space bar swiped across it to switch the typing language:
/// it went sideways at least `minimumTravelShare` of the space bar's own width, more sideways than
/// up or down, and the cursor trackpad never took it. A short slide, or a hold followed by a small
/// move, never switches, however long the finger stayed down. The trackpad starts only on a finger
/// held still, so a finger held into the trackpad moves the cursor and never switches.
nonisolated enum KeyboardSpaceLanguageSlide {
    /// How much of the space bar's width the finger must cross, so only a swipe from one end of the
    /// bar toward the other switches.
    static let minimumTravelShare: CGFloat = 0.5

    /// How far sideways the finger must go on a space bar `spaceBarWidth` points wide.
    static func minimumTravel(spaceBarWidth: CGFloat) -> CGFloat {
        spaceBarWidth * minimumTravelShare
    }

    /// One place forward for a swipe to the right, one back for a swipe to the left, or nil when the
    /// finger did not swipe across a space bar `spaceBarWidth` points wide.
    static func offset(
        from start: CGPoint,
        to end: CGPoint,
        spaceBarWidth: CGFloat,
        trackpadWasActive: Bool
    ) -> Int? {
        guard trackpadWasActive == false, spaceBarWidth > 0 else { return nil }
        let horizontal = end.x - start.x
        let vertical = end.y - start.y
        guard abs(horizontal) >= minimumTravel(spaceBarWidth: spaceBarWidth),
              abs(horizontal) > abs(vertical) else { return nil }
        return horizontal > 0 ? 1 : -1
    }
}
