import KeyVoxPredictiveKeyboard
import UIKit

/// Swipe typing on the key grid.
///
/// A finger that lands on a letter key of the full letter page, while swipe typing is on and
/// nothing else holds the keys, is followed by the swipe gate (`SwipeGate`) with every sample
/// the screen reports. Until the gate makes it a swipe it is an ordinary key press in every way;
/// once it does, its key lets go, the trail follows it, and its path is handed on as a word when
/// it lifts or another finger lands. A finger the gate leaves undecided at its lift types its key
/// when the next finger lands within the gate's window, before that finger's key, and is handed on
/// as a word when none does. While swipe typing is off the gate never runs.
extension KeyboardKeyGridView {
    /// Starts following `session` for the swipe gate when it may become a swipe.
    func beginSwipeTracking(_ session: KeyboardKeyTouchSession, for touch: UITouch, onKey keyView: KeyboardKeyView?) {
        guard allowsSwipeTyping else { return }
        let isEligible = keyView.map(isSwipeEligible) ?? false
        swipeGate.touchBegan(
            ObjectIdentifier(touch),
            at: session.location,
            time: touch.timestamp,
            pitch: Double(letterKeyPitch),
            isEligible: isEligible
        )
        if isEligible {
            session.swipePath = [SwipeTouchSample(location: session.location, timestamp: touch.timestamp)]
        }
    }

    /// Follows a moving finger the gate is watching or that is swiping. Returns true when the
    /// finger is swiping, so the move is the swipe's and not a key press's.
    func followSwipe(_ session: KeyboardKeyTouchSession, for touch: UITouch, event: UIEvent) -> Bool {
        guard allowsSwipeTyping, session.swipePath.isEmpty == false else { return false }
        // A held key's open popup has the finger now, choosing a character.
        if session === heldKeyTouchSession, heldKeyController.hasOpened {
            session.swipePath = []
            return false
        }
        let samples = (event.coalescedTouches(for: touch) ?? [touch]).map {
            SwipeTouchSample(location: $0.location(in: self), timestamp: $0.timestamp)
        }
        session.swipePath += samples
        if session.isSwipe {
            swipeTrailView.extend(with: samples)
            return true
        }
        let id = ObjectIdentifier(touch)
        guard samples.contains(where: { swipeGate.touchMoved(id, to: $0.location, time: $0.timestamp) }) else {
            // Another finger landed, so this one can no longer swipe.
            if swipeGate.isSwipe(id) == false, touchSessions.count > 1 {
                session.swipePath = []
            }
            return false
        }
        promoteToSwipe(session)
        return true
    }

    /// Settles a lifting finger the gate follows. Returns true when it is not a key press: a swipe,
    /// handed on as a word, or undecided, waiting on the next finger.
    func followSwipeLift(_ session: KeyboardKeyTouchSession, for touch: UITouch) -> Bool {
        guard allowsSwipeTyping else { return false }
        let id = ObjectIdentifier(touch)
        guard session.swipePath.isEmpty == false else {
            swipeGate.touchCancelled(id)
            return false
        }
        let lift = SwipeTouchSample(location: touch.location(in: self), timestamp: touch.timestamp)
        session.swipePath.append(lift)
        switch swipeGate.touchEnded(id, at: lift.location, time: lift.timestamp) {
        case .tap:
            return false
        case .swipe:
            if session === heldKeyTouchSession {
                cancelHeldKey()
            }
            endSwipe(session)
            return true
        case .undecided:
            if session === heldKeyTouchSession {
                cancelHeldKey()
            }
            undecidedSwipeSessions[id] = session
            let window = swipeGate.parameters.undecidedWindow
            DispatchQueue.main.asyncAfter(deadline: .now() + window) { [weak self] in
                self?.settleUndecidedSwipes(at: ProcessInfo.processInfo.systemUptime)
            }
            return true
        }
    }

    /// Hands on as words the undecided fingers no finger landed after within the gate's window by
    /// `time`; `.infinity` hands them all on, as when the user moves on to the suggestion bar.
    func settleUndecidedSwipes(at time: TimeInterval) {
        guard undecidedSwipeSessions.isEmpty == false else { return }
        for id in swipeGate.settleUndecided(at: time) {
            guard let session = undecidedSwipeSessions.removeValue(forKey: id) else { continue }
            onSwipeEnded?(session.swipePath)
        }
    }

    /// Types the keys of the undecided fingers a landing finger makes taps, in the order they
    /// lifted.
    func typeUndecidedTouches() {
        guard allowsSwipeTyping else { return }
        for id in swipeGate.settleUndecidedAsTaps() {
            guard let session = undecidedSwipeSessions.removeValue(forKey: id), let kind = session.kind else { continue }
            deliver(kind, from: session)
        }
    }

    /// Hands on every swipe under way as a word, as when another finger lands.
    func endSwipes() {
        for (id, session) in touchSessions where session.isSwipe {
            touchSessions[id] = nil
            swipeGate.touchCancelled(id)
            endSwipe(session)
        }
    }

    /// Hands on `session`'s path as a word and lets its trail fade.
    func endSwipe(_ session: KeyboardKeyTouchSession) {
        swipeTrailView.lift()
        onSwipeEnded?(session.swipePath)
    }

    /// Forgets every finger the gate follows, undecided ones included, and any swipe under way,
    /// typing nothing.
    func cancelSwipeTracking() {
        swipeGate.reset()
        undecidedSwipeSessions.removeAll()
        swipeTrailView.cancel()
        for session in touchSessions.values {
            session.swipePath = []
        }
        touchSessions = touchSessions.filter { $0.value.isSwipe == false }
    }

    /// Lets go of the key the finger was pressing, which then types nothing, and starts its trail.
    private func promoteToSwipe(_ session: KeyboardKeyTouchSession) {
        session.isSwipe = true
        if session === heldKeyTouchSession {
            cancelHeldKey()
        }
        if let keyView = session.keyView {
            dismissPopup(ownedBy: keyView)
            session.keyView = nil
            if touchSessions.values.contains(where: { $0.keyView === keyView }) == false {
                setVisualState(.normal, for: keyView)
            }
        }
        swipeTrailView.begin(with: session.swipePath)
    }

    /// Whether a finger landing on `keyView` may become a swipe: a single letter key of the full
    /// letter page outside the emoji search, with no held key's popup or trackpad under way and
    /// VoiceOver off.
    private func isSwipeEligible(_ keyView: KeyboardKeyView) -> Bool {
        guard symbolPage == .letters, keysMode == .full, isEmojiSearch == false,
              spaceTrackpadController.isActive == false, heldKeyController.hasOpened == false,
              UIAccessibility.isVoiceOverRunning == false, letterKeyPitch > 0,
              case let .character(value) = keyView.model.kind, value.count == 1 else {
            return false
        }
        return value.first?.isLetter == true
    }
}
