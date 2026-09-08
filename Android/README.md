# Android host

The Android application and input method live here. The containing application
owns setup and platform entry points. The IME owns the editor connection and its
replaceable presentation. Shared Swift processing remains in `Packages/`.

Open this directory in Android Studio. Use its bundled JDK, or a compatible JDK,
and configure the installed Android SDK through `local.properties` or
`ANDROID_HOME`. Stage the engine first, then build with `./gradlew :app:assembleDebug`. The Gradle wrapper pins
8.13 and verifies its distribution checksum; the Android plugin is pinned to
8.13.2. The application targets API 36 and supports API 28 onward.

## Engine build

Build the existing Android Whisper prefix using `Tools/build-portable-whisper.sh`.
Then supply the installed Swift 6.3.3 compiler, Android SDK shared-library
directory, NDK, Whisper prefix, and an external scratch directory:

```sh
python3 build-engine.py --swift "$SWIFT_COMPILER" \
  --sdk-libraries "$SWIFT_ANDROID_LIBRARIES" --ndk "$ANDROID_NDK_HOME" \
  --whisper-prefix "$WHISPER_PREFIX" --scratch /tmp/keyvox-android-engine-build
./gradlew :app:assembleDebug
```

The script follows actual ELF dependencies, copies unchanged SwiftPM resource
bundles and their notices, and stages the result under `app/build/generated/engine`.
Repeat staging after engine/package changes or `gradlew clean`. Gradle fails if
the staged engine is missing. Only arm64 is currently packaged. The generated
native inventory records pre-packaging hashes; Android packaging can strip symbols.

## Current capability

- FUNCTIONAL: installable containing app, keyboard setup links, system IME
  registration, keyboard switching, and basic editor operations.
- FUNCTIONAL: editor connection generation changes reject stale destination
  handles. This is a connection primitive, not a completed transcript delivery
  policy.
- FUNCTIONAL: installed JNI/Swift bridge, shared Whisper service, Silero VAD,
  and real Core processing of a caller-provided speech recording.
- FUNCTIONAL: app-owned download and SHA-256 verification of the exact shared
  iOS Whisper Base artifact. Weights are downloaded, not bundled in the APK.
- FUNCTIONAL: microphone start from the keyboard in another app; capture continues
  after Home. Keyboard cancellation releases capture, and a subsequent recording
  starts. Stop runs captured samples through the engine and returns to idle.
- UNRESOLVED: full iOS insertion/composition parity, warm idle microphone sessions,
  lock-screen/interruption recovery, process-death recovery, language/settings UI,
  dictionary editing, statistics, and resumable onboarding download behavior.

The containing app has no dictation controls. Start/stop/cancel belong to the
keyboard. A process-owned `DictationSession` publishes semantic state; the Android
service owns microphone and processing lifetime. The platform-required foreground
notice has no dictation action buttons. Results target the original editor
generation; if that connection changes, text is retained in session memory and is
not automatically inserted into another field. Product recovery UX remains open.

The bridge's `ModelArtifactInstaller` depends directly on `KeyVoxModels`; Core
does not acquire a model-management dependency. Core accepts an explicit resource
bundle before first access, and Whisper accepts a VAD factory; ordinary Apple
defaults remain unchanged. No lexicon or common-word contents are regenerated.

`EngineBridge/Sources/CAndroidEngine/AndroidMainLoop.c` isolates Swift 6.3.3
libdispatch's CoreFoundation main-queue integration SPI. Android's main Looper
drains the dispatch eventfd, allowing MainActor and DispatchQueue.main to execute
on the Android main thread. This is a pinned compatibility adapter, not a stable
Swift API; revalidate it before changing the toolchain. JNI transports result text
as UTF-8 bytes, preserving non-BMP characters.

The release app has no dictation text field. `EditorTestActivity` exists only in
the debug source set and can be launched with:

```sh
adb shell am start -n org.keyvox.android/.debug.EditorTestActivity
```

The minimal controls are integration surfaces, not the product design. Activity
visibility and IME view visibility must not become owners of microphone lifetime.
No iOS source is extracted or modified by this host.

## Validation

```sh
./gradlew :app:assembleDebug :app:assembleRelease :app:assembleDebugAndroidTest :app:lintDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w org.keyvox.android.test/org.keyvox.android.ime.ShellInstrumentation
adb shell am instrument -w -e capture true org.keyvox.android.test/org.keyvox.android.ime.ShellInstrumentation
adb shell am instrument -w -e fixture fixture.f32 org.keyvox.android.test/org.keyvox.android.ime.ShellInstrumentation
```

The platform instrumentation runner exercises editor replacement, detachment,
and selection deletion without introducing a third-party test runtime.
Physical-device checks also need to exercise the actual IME window, its
navigation-bar insets, and editor operations. SDK platform and framework APIs
remain Android-owned; they are not bundled in the APK.

Capture checks require microphone permission, an unlocked device, and verified
Base weights. The fixture check requires a caller-provided mono 16 kHz Float32
little-endian PCM file in app-private files. Recordings are not distributed as test
assets. It verifies real nonempty processed output, not recognition accuracy.

Foundation validation: 572 Core tests passed on the Apple host. Android debug and
release APKs build, lint passes, and physical Android 16 instrumentation passes
editor lifetime/no-speech selection checks, repeated microphone cancel/restart,
Stop through processing, and real speech-fixture inference. The device also
demonstrated external-app keyboard start and continued capture after Home.
Both APKs include 19 native libraries with retained dependency/resource notices;
their staged ELF load segments satisfy 16 KB alignment. Other Android versions,
lock-screen behavior, and complete iOS dictation parity remain unverified.

## Distribution

The app adds no third-party Java/UI runtime. The existing Swift 6.3.3 runtime
family is Apache-2.0 with its runtime exception; Foundation's ICU/data and
networking dependencies retain their separate permissive notices. Whisper and
Silero are MIT. Swift Crypto 4.5.2 and its recorded bundled components retain
Apache-2.0/BoringSSL/Fiat/XKCP notices; Swift ASN.1 1.7.2 is a resolved build
dependency. NDK libc++ retains the LLVM/NDK notices. Core's existing lexicon,
common-word and file-type data retain their individual licenses. See
`../Tools/Licenses` and the packaged resource notices for exact provenance and
terms. The APK contains both notice sets. The audited Swift package dependency
versions are pinned in `EngineBridge/Package.resolved`.
