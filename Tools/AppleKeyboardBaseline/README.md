# Apple keyboard baseline

Replays a typing plan from `Tools/KeyVoxTypingHarness` on the iOS system keyboard in
the Simulator, so KeyVox's predictive keyboard can be scored against Apple's on the
exact same finger taps. Every tap is an offset from the intended key's center in key
pitches, so both keyboards receive the same fingers on their own key sizes.

The host app is one text view with system autocorrection on and auto-capitalization,
smart punctuation, and inline predictions off, so the recorded text reflects
autocorrect alone.

## Run

Use a freshly erased simulator so the system keyboard has learned nothing:

```sh
xcrun simctl erase "<simulator-udid>"
```

Write a plan, replay it on the system keyboard, then compare:

```sh
cd Tools/KeyVoxTypingHarness
swift run -c release --scratch-path /tmp/keyvox-typing-harness KeyVoxTypingHarness \
  plan --corpus <corpus> --sentences 60 --noise 0.3 --output /tmp/typing-plan.json

cd ../AppleKeyboardBaseline
TEST_RUNNER_BASELINE_PLAN=/tmp/typing-plan.json \
TEST_RUNNER_BASELINE_OUTPUT=/tmp/apple-results.json \
xcodebuild test -project AppleKeyboardBaseline.xcodeproj -scheme BaselineUITests \
  -destination "platform=iOS Simulator,id=<simulator-udid>" \
  -derivedDataPath /tmp/keyvox-apple-baseline

cd ../KeyVoxTypingHarness
swift run -c release --scratch-path /tmp/keyvox-typing-harness KeyVoxTypingHarness \
  compare --plan /tmp/typing-plan.json --apple /tmp/apple-results.json
```

The Simulator must show the software keyboard (I/O > Keyboard > Connect Hardware
Keyboard off). Results are rewritten after every sentence, so an interrupted run keeps
its progress.

## Replay on the KeyVox keyboard

Install the KeyVox app on a separate simulator, then add the KeyVox keyboard with Full
Access:

```sh
TEST_RUNNER_SETUP_KEYBOARD_NAME=KeyVox \
xcodebuild test -project AppleKeyboardBaseline.xcodeproj -scheme BaselineUITests \
  -destination "platform=iOS Simulator,id=<simulator-udid>" \
  -derivedDataPath /tmp/keyvox-apple-baseline \
  -only-testing:BaselineUITests/KeyboardSetupTests
```

Replay the same plan with `TEST_RUNNER_BASELINE_KEYBOARD_MARKER=Shift` (a key label only
the KeyVox keyboard has) and `TEST_RUNNER_BASELINE_KEYBOARD_NAME=KeyVox`. Add
`TEST_RUNNER_BASELINE_DISABLE_AUTOCORRECT=1` to record the raw typed letters instead.

## Delete key timeline

The host app records every change to its text, with the time since it was filled, to
`Documents/deletion-timeline.json`. Tap Fill (sentences of made-up words), Long (26-letter
words), or Lines (a sentence per line), hold the keyboard's delete key, then print what
each step removed and when:

```sh
python3 print_deletion_timeline.py --simulator <simulator-udid> --save <timeline.json>
```

## Swipe trail capture

`SwipeTrailCaptureTests` swipes words across the KeyVox keyboard for recording its swipe
trail. Each word is one finger drawn through its letters' key centers with XCTest's event
synthesis, in minimum-jerk strokes that slow into every key; the Simulator keeps a
synthesized path's timing only when its points are sparse, so they are given at 20 Hz and the
keyboard still sees the screen's own samples in between. Record the screen alongside:

```sh
xcrun simctl io <simulator-udid> recordVideo --codec=h264 --force swipes.mov &
TEST_RUNNER_SWIPE_KEYBOARD_MARKER=Shift \
TEST_RUNNER_SWIPE_WORDS=hello,world,keyboard \
TEST_RUNNER_SWIPE_OUTPUT=/tmp/swipes.json \
xcodebuild test -project AppleKeyboardBaseline.xcodeproj -scheme BaselineUITests \
  -destination "platform=iOS Simulator,id=<simulator-udid>" \
  -derivedDataPath /tmp/keyvox-apple-baseline -parallel-testing-enabled NO \
  -only-testing:BaselineUITests/SwipeTrailCaptureTests
kill -INT %1
```

`TEST_RUNNER_SWIPE_PAUSE` sets the rest after each swipe (default 1.2 s). The output holds
each swipe's wall-clock start and end, for picking frames of the recording, and the text the
swipes typed.
