# Running shared package tests on Android

The installed Swift Android SDK includes XCTest. Existing package assertions run
on the phone directly, with the same fixtures and expectations used on Apple.
This diagnostic uses shared test libraries; the engine's static Swift build
remains a separate validation.

## Build and execution

From the package directory, use the Android-capable Swift toolchain:

```sh
"$ANDROID_SWIFT" build --build-tests \
  --swift-sdk aarch64-unknown-linux-android28 \
  --scratch-path /tmp/keyvox-core-device-tests \
  -Xcc -I/tmp/keyvox-whisper-android/include \
  -Xlinker -L/tmp/keyvox-whisper-android/lib \
  -Xlinker -lc++_shared
```

`ANDROID_SWIFT` is the installed Swift 6.3.3 executable. The native Whisper prefix
comes from the existing portable Whisper build. Omit `--static-swift-stdlib` for
this test executable because the SDK supplies shared XCTest libraries.

Deploy `KeyVoxCorePackageTests.xctest` and every `.resources` directory from the
build's `aarch64-unknown-linux-android28/debug` directory to a dedicated directory
under `/data/local/tmp`. Put the required shared libraries beside the executable.
The exact measured library names and hashes are in
[`testing-runtime.json`](../../Tools/Licenses/Swift-Android/testing-runtime.json).
SDK libraries come from `swift-resources/usr/lib/swift-aarch64/android`; the C++
library comes from the configured NDK's arm64 sysroot. Android supplies the listed
system libraries. Recheck the ELF dependency closure if the SDK or package changes.

Run with `LD_LIBRARY_PATH` and `TMPDIR` set to that device directory:

```sh
adb -s "$ANDROID_SERIAL" shell \
  "LD_LIBRARY_PATH=$DEVICE_TEST_DIR TMPDIR=$DEVICE_TEST_DIR $DEVICE_TEST_DIR/KeyVoxCorePackageTests.xctest"
```

Retain the exit code and complete output. A nonzero result must not be relabeled
as a passing run. Use a dedicated directory without spaces for this command.
Whisper's suite follows the same steps with `KeyVoxWhisperPackageTests.xctest`.
These test runtimes and executables are diagnostic artifacts, not app dependencies.

Main-actor test methods use XCTest's asynchronous entry point so discovery can
preserve their actor isolation. Expectation waits inside those tests also suspend
asynchronously. Test assertions and fixtures remain shared with Apple.

## Measured checkpoint

- Whisper: **27 tests passed on Android**; the Apple suite has 28 because its
  platform-specific context initialization coverage differs.
- Core: **567 tests executed on both platforms**. Apple passed all 567. Android
  passed 491 and failed 76, with 122 failed assertions and zero unexpected failures.
- All Core assertions remain enabled. The Android run uses the default portable
  analyzer, not the optional host-selected grammatical model.

| Android failed assertions by existing fixture file | Count |
| --- | ---: |
| DictationPipelineTests | 20 |
| DictionaryMatcherTests | 9 |
| ListFormattingEngineTests | 4 |
| ListPatternDetectorTests | 10 |
| TerminalPeriodNormalizerTests | 1 |
| TerminalPunctuationNormalizerTests | 13 |
| TranscriptionPostProcessorTests | 7 |
| TranscriptionPostProcessorTests+CapitalizationAndTime | 7 |
| TranscriptionPostProcessorTests+LanguageHeuristics | 5 |
| TranscriptionPostProcessorTests+NumericGrouping | 42 |
| TranscriptionPostProcessorTests+DateNormalization | 1 |
| WhisperSegmentTextAssemblerTests | 3 |

These are assertion counts, not distinct root causes. Several pipeline failures
reflect the same downstream list behavior. Missing semantic detection and roles
are known gaps; each remaining difference still needs its own causal check before
changing engine behavior. Passing these package tests would not establish full
Android app or background-dictation parity.

The initial executable baseline had 127 failed assertions across 81 cases.
Requiring complete consumption of spelled-out number candidates closed four math
cases and one spoken-date case without changing their expectations. Two additional
parser tests cover generated number phrases and rejection of unparsed suffixes.

## Test runtime licensing

XCTest and Swift Testing use Apache-2.0 with the Swift Runtime Library Exception.
Their matching release notices are retained in the runtime inventory above.
Existing Swift, Foundation, Dispatch, ICU, and Android C++ notices also apply to
the measured shared-library closure. No model, lexicon, corpus, or new test dataset
is introduced by running the existing assertions.
