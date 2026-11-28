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

## Dismissing the keyboard

The host app's Hide button dismisses the keyboard and Show brings it back to the text view, for
steps that need the keyboard to go away and appear again (`button:Hide`, then `button:Show`, in
`EmojiFrequentlyUsedProbeTests`).

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

## Swiped words

`SwipeWordsValidationTests` checks what swipes type on the KeyVox keyboard, or on the system
keyboard with `TEST_RUNNER_SWIPE_SYSTEM_KEYBOARD=1` (picked from the globe's menu where there is
one). Each case clears the text, types its words before by tapping the keys, and swipes its keys
the same way (`SwipeGesturePath`), looping around the keys it names: by default the finger curls
once around the key's center and goes a tenth of a turn past where the loop crosses, as people
loop at a doubled letter; a case's `loop` (`SwipeGesturePath.Loop`: `radius` and `drift` in key
pitches, `duration` and `pause` in seconds, `turns`) shapes it otherwise.

```sh
TEST_RUNNER_SWIPE_KEYBOARD_MARKER=Shift \
TEST_RUNNER_SWIPE_CASES='[{"before":"i want","keys":"to","loops":[1]},{"before":"","keys":"to","loops":[]}]' \
TEST_RUNNER_SWIPE_OUTPUT=/tmp/swiped-words.json \
xcodebuild test -project AppleKeyboardBaseline.xcodeproj -scheme BaselineUITests \
  -destination "platform=iOS Simulator,id=<simulator-udid>" \
  -derivedDataPath /tmp/keyvox-apple-baseline -parallel-testing-enabled NO \
  -only-testing:BaselineUITests/SwipeWordsValidationTests
```

`before` is the words before, space separated (empty for a sentence start), `keys` the keys to
swipe through, and `loops` the indices of the keys to loop around. The output holds each case
with where its swipe started, `path` (the points sent, as screen x, y and seconds), the text it
left, and `bar`, the suggestion bar's entries then; each case's result is also printed as a
`SWIPE_CASE_RESULT` line, for a device, whose output file stays on the device. Each case's
screenshot is kept in the test's results, and in `TEST_RUNNER_SWIPE_SCREENSHOTS`, when set, as a
PNG.

## Web endings

`write_web_endings.py` writes the web endings Apple's keyboard lists for each locale, read from an
iOS simulator runtime's own keyboard files (`System/Library/TextInput/TextInput_*.bundle/Keyboard-*.plist`,
`UI-TopLevelDomain`), into the predictive keyboard's `PredictiveData/web_endings.json`, with how
many of the region's endings Apple's keyboard places right of the key's own, as measured on the
iOS 27.2 simulator (`~/KeyVoxLanguageData/apple-languages/runs/sim-weburl-summary.md`):

```sh
python3 write_web_endings.py "<runtime>/Contents/Resources/RuntimeRoot/System/Library/TextInput" \
  ../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/web_endings.json
```

## Emoji in each language

`EmojiLanguageProbeTests` plays a script of steps, a JSON array its file's comment describes, on
whichever keyboard is in use: picking a keyboard from the globe's menu, opening the emoji keyboard,
typing a word into its search field and recording the results shown, typing a word and recording
the suggestion bar, tapping elements by label or the screen at a point, and saving screenshots and
the labeled elements. It recorded the system emoji search with each language's keyboard for
`Tools/KeyVoxEmojiData` ("Measured on the system keyboard" there), and plays the same steps on the
KeyVox keyboard. `SettingsScriptProbeTests` plays steps in the Settings app the same way, such as
adding a language's keyboard.

```sh
TEST_RUNNER_EMOJI_LANGUAGE_SCRIPT=/tmp/steps.json \
TEST_RUNNER_EMOJI_LANGUAGE_OUTPUT=/tmp/emoji-language.json \
xcodebuild test -project AppleKeyboardBaseline.xcodeproj -scheme BaselineUITests \
  -destination "platform=iOS Simulator,id=<simulator-udid>" \
  -derivedDataPath /tmp/keyvox-apple-baseline -parallel-testing-enabled NO \
  -only-testing:BaselineUITests/EmojiLanguageProbeTests
```

with `/tmp/steps.json` holding, for example, `["pick:Deutsch (Deutschland)", "emoji", "search:Hund"]`.
`SettingsScriptProbeTests` reads its steps from `TEST_RUNNER_SETTINGS_SCRIPT` and saves into
`TEST_RUNNER_SETTINGS_SCRIPT_OUTPUT_DIR`.
