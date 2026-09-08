# Android host

The Android application and input method live here. The containing application
owns setup and platform entry points. The IME owns the editor connection and its
replaceable presentation. Shared Swift processing remains in `Packages/`.

Open this directory in Android Studio. Use its bundled JDK, or a compatible JDK,
and configure the installed Android SDK through `local.properties` or
`ANDROID_HOME`. Build with `./gradlew :app:assembleDebug`. The Gradle wrapper pins
8.13 and verifies its distribution checksum; the Android plugin is pinned to
8.13.2. The application targets API 36 and supports API 28 onward.

## Current capability

- FUNCTIONAL: installable containing app, keyboard setup links, system IME
  registration, keyboard switching, and basic editor operations.
- FUNCTIONAL: editor connection generation changes reject stale destination
  handles. This is a connection primitive, not a completed transcript delivery
  policy.
- UNRESOLVED: microphone/session service, in-app Swift bridge, model installation,
  and keyboard dictation. The separate speech harness already exercises the Swift
  pipeline; this application does not yet embed it.

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
```

The platform instrumentation runner exercises editor replacement, detachment,
and selection deletion without introducing a third-party test runtime.
Physical-device checks also need to exercise the actual IME window, its
navigation-bar insets, and editor operations. SDK platform and framework APIs
remain Android-owned; they are not bundled in the APK.
