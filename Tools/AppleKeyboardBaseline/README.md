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
