# Android microphone capture harness

A diagnostic host for the platform microphone. It records mono 16 kHz PCM16 WAV
files for the existing Swift `file-pipeline` command. This does not select a
production frontend architecture or bundle a speech model.

## Build

Use an already installed Android SDK and JDK:

```sh
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export KEYVOX_JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
bash Tools/AndroidCaptureHarness/build.sh /tmp/keyvox-android-capture-build
KEYVOX_JAVA_HOME="$KEYVOX_JAVA_HOME" python3 -m unittest discover -s Tools/AndroidCaptureHarness/tests -v
adb install -r /tmp/keyvox-android-capture-build/KeyVoxCaptureHarness.apk
adb shell am start -n org.keyvox.platformlab.capture/.CaptureActivity
```

The build uses SDK platform 36 and build-tools 36.1.0 by default, with optional
`ANDROID_PLATFORM` and `ANDROID_BUILD_TOOLS_VERSION` overrides. The verified JDK
was the installed JetBrains Runtime 21.0.10. Every build uses a fresh child
directory for classes and dex output. A local debug signing key is retained in
the selected temporary output directory so incremental installs preserve files.
The APK is a debuggable diagnostic build, not a release artifact.

## Capture and execute

Tap Record, allow microphone permission, speak, then tap Stop. Leaving the
foreground requests a stop. Completed captures have unique `.wav` names in:

```text
/sdcard/Android/data/org.keyvox.platformlab.capture/files/
```

Failures retain the available file and display its location. A `.partial` file
may be incomplete and is not advertised as a successful recording. Captures are
never added to the repository. The host has no network permission.

Use the existing deployed Swift harness on the same phone:

```sh
adb shell 'LD_LIBRARY_PATH=/data/local/tmp/keyvox-platform-lab /data/local/tmp/keyvox-platform-lab/KeyVoxSpeechHarness file-pipeline /data/local/tmp/keyvox-platform-lab/model.bin /sdcard/Android/data/org.keyvox.platformlab.capture/files/CAPTURE.wav'
```

The recorder and Swift engine communicate through a WAV file. The command is
currently orchestrated through adb; this does not claim an in-app Swift bridge.

## Licensing and provenance

- All incorporated Java source, resources, and build code are first-party MIT
  material. The APK retains the project license as `assets/KEYVOX-LICENSE.txt`.
- Android `AudioRecord`, `Activity`, and other framework APIs are supplied by the
  operating system. No framework implementation is copied into this APK. The
  reviewed Android 16 API sources carry Apache-2.0 headers:
  [AudioRecord](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-16.0.0_r1/media/java/android/media/AudioRecord.java),
  [Activity](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-16.0.0_r1/core/java/android/app/Activity.java).
- The installed SDK and JDK are build tools, not shipped dependencies. The JDK's
  GPLv2/Classpath-exception notices concern that installed tool distribution; no
  JDK classes or runtime are bundled with the APK. This harness does not adopt or
  redistribute a GPL runtime, SDK, or compiler.
- APK inspection found only the manifest, resource table, project MIT notice,
  signing metadata, and dex code. All 12 defined classes belong to the first-party
  capture namespace. No native libraries, support libraries, models, datasets,
  corpora, or other third-party assets are included.

## Validation

The APK builds, verifies its signature, installs, and launches on the connected
SM-S948U1. The WAV writer passes independent Python decoding checks for signed
sample limits, multiple writes, several sample rates, and immediate-stop empty
files. Deterministic first-party JVM doubles verify stop-before-start, repeated
start, normal stop, read failure, release failure, single completion/release, and
preserved partial/completed files. These doubles are excluded from APK sources
and establish control-flow behavior independently of hardware.

Actual microphone capture and Swift inference executed on the SM-S948U1:
89,600 mono samples (5.6 seconds), one VAD speech segment selecting 73,600 samples,
and a real transcript passed through Core with 11 word tokens and eight supported
grammatical roles. The audio stayed on the phone; adb orchestrated the existing
Swift executable. The capture view applies platform system-bar insets and uses no
overlapping action bar, verified from the device hierarchy before recording.
