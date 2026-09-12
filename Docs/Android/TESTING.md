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

- KeyVoxModels: **2 tests passed on both Apple and Android**, covering locally
  generated empty, short, and multi-chunk file digests, progress, input preservation,
  and missing-file/directory errors.
- Whisper: **27 tests passed on Android**; the Apple suite has 28 because its
  platform-specific context initialization coverage differs.
- Core: the recorded bakeoff ran **582 tests on both Apple and Android**, with
  identical fixtures and expectations, zero failed assertions, and zero
  unexpected failures.
- The measured pre-bakeoff Android baseline was **496 / 572**, with 122 failed
  assertions across 76 cases. These current measurements replace historical
  counts.
- All Core assertions remain enabled. Ten new portable regressions cover cases
  exposed by held-out and cross-platform comparison.

The full candidate matrix, exact per-failure ledger, semantic traces, performance,
distribution cost, and licensing gate are in the
[Core linguistic bakeoff](CORE_LINGUISTIC_BAKEOFF.md). Passing package tests is
necessary but is not treated as proof of the real Android dictation path; that
separate NPU inference evidence is recorded there too.

## Selected analyzer comparison

The same Core suite can run with an explicitly selected grammatical model and
lexical database. The production Android engine selects the same combination
from host-owned assets; Apple retains its native analyzer.
The first-party runner in
[`ModelSelectedTestRunner.swift`](../../Tools/AndroidCoreTests/ModelSelectedTestRunner.swift)
uses SwiftPM's generated test discovery and supplies the analyzer through the
existing task-local capability. No assertions, fixtures, or exclusions change.

Add this option to the build command above, using a separate scratch directory:

```sh
--experimental-test-entry-point-path "$REPOSITORY_ROOT/Tools/AndroidCoreTests/ModelSelectedTestRunner.swift"
```

Deploy this build under a distinct executable name, such as
`KeyVoxCoreRolesTests.xctest`, beside the same test libraries and resources. Set
`KEYVOX_LINGUISTIC_MODEL` to the perceptron directory,
`KEYVOX_LEXICAL_DATABASE` to the WordNet 3.0 directory, and
`KEYVOX_LINGUISTIC_LANGUAGE` to the explicit language identifier, in addition to
`LD_LIBRARY_PATH` and `TMPDIR`. The first two settings are required for the final
selected configuration. The runner emits an exact implementation identity and
per-call semantic outputs, proving which provider reaches each decision. The
entry-point option was exercised with Swift 6.3.3.

Raw perceptron measurement remains a useful rejected-candidate checkpoint:
**525 / 572**, 54 failed assertions across 47 cases. The selected bakeoff
combination reached **582 / 582** on both platforms. It adds contextual role resolution, name identity, noun inflection,
WordNet lexical evidence, and portable numeric date/address protection without a
new code runtime dependency. This is text-language behavior evidence, not a claim
about multilingual speech-recognition accuracy.

## Test runtime licensing

XCTest and Swift Testing use Apache-2.0 with the Swift Runtime Library Exception.
Their matching release notices are retained in the runtime inventory above.
Existing Swift, Foundation, Dispatch, ICU, and Android C++ notices also apply to
the measured shared-library closure. The optional model assets retain their own
licenses and pinned provenance as documented in the bakeoff record.
