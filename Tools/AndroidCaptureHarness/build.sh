#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?Pass an absolute temporary build directory}"
sdk_root="${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT}"
jdk_root="${KEYVOX_JAVA_HOME:?Set KEYVOX_JAVA_HOME to an installed JDK}"
tools_version="${ANDROID_BUILD_TOOLS_VERSION:-36.1.0}"
platform="${ANDROID_PLATFORM:-android-36}"
build_tools="$sdk_root/build-tools/$tools_version"
android_jar="$sdk_root/platforms/$platform/android.jar"
export JAVA_HOME="$jdk_root"

case "$output_dir" in /*) ;; *) echo "Build directory must be absolute" >&2; exit 1;; esac
mkdir -p "$output_dir"
work_dir="$(mktemp -d "$output_dir/work.XXXXXX")"
mkdir -p "$work_dir/generated" "$work_dir/classes" "$work_dir/dex" "$work_dir/assets"
cp "$source_dir/../../LICENSE.md" "$work_dir/assets/KEYVOX-LICENSE.txt"
"$build_tools/aapt2" compile --dir "$source_dir/res" -o "$work_dir/resources.zip"
"$build_tools/aapt2" link -I "$android_jar" -A "$work_dir/assets" --manifest "$source_dir/AndroidManifest.xml" \
    --min-sdk-version 28 --target-sdk-version 36 --java "$work_dir/generated" \
    -o "$work_dir/unsigned.apk" "$work_dir/resources.zip"
"$jdk_root/bin/javac" -source 8 -target 8 -bootclasspath "$android_jar" \
    -d "$work_dir/classes" \
    "$work_dir/generated/org/keyvox/platformlab/capture/R.java" \
    "$source_dir/src/org/keyvox/platformlab/capture/"*.java
"$jdk_root/bin/jar" cf "$work_dir/classes.jar" -C "$work_dir/classes" .
"$build_tools/d8" --lib "$android_jar" --min-api 28 --output "$work_dir/dex" "$work_dir/classes.jar"
(cd "$work_dir/dex" && /usr/bin/zip -q -j "$work_dir/unsigned.apk" classes.dex)
"$build_tools/zipalign" -f 4 "$work_dir/unsigned.apk" "$work_dir/aligned.apk"
if [ ! -f "$output_dir/debug.keystore" ]; then
    "$jdk_root/bin/keytool" -genkeypair -keystore "$output_dir/debug.keystore" \
        -alias androiddebugkey -storepass android -keypass android -keyalg RSA \
        -dname "CN=KeyVox Capture Harness" -validity 3650
fi
"$build_tools/apksigner" sign --ks "$output_dir/debug.keystore" --ks-key-alias androiddebugkey \
    --ks-pass pass:android --key-pass pass:android --out "$output_dir/KeyVoxCaptureHarness.apk" "$work_dir/aligned.apk"
"$build_tools/apksigner" verify "$output_dir/KeyVoxCaptureHarness.apk"
echo "$output_dir/KeyVoxCaptureHarness.apk"
