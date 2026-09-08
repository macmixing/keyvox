# Android build and runtime provenance

The initial application declares **no external runtime dependencies**. The APK
contains first-party application code, generated resource/lambda code, and
resources. Android framework classes are supplied by the operating system.

## Incorporated build bootstrap

The standard Gradle 8.13 wrapper (scripts and wrapper JAR) is Apache-2.0 licensed.
It was generated using the verified upstream Gradle distribution. The wrapper
JAR contains Gradle wrapper/CLI/helper classes and its embedded license, not the
full Gradle distribution's third-party libraries.

- Distribution: https://services.gradle.org/distributions/gradle-8.13-bin.zip
- Official checksum: https://services.gradle.org/distributions/gradle-8.13-bin.zip.sha256
- Distribution SHA-256: `20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78`
- Wrapper JAR SHA-256: `81a82aaea5abcc8ff68b3dfcb58b3c3c429378efd98e7433460610fecd7ae45f`

The unmodified upstream license and notice are retained alongside this record.
Their inventory covers more than the wrapper itself.

## External build tools, not app dependencies

Android Gradle Plugin `com.android.tools.build:gradle:8.13.2` is Apache-2.0
licensed; its AOSP/Gradle source notices were checked in the published source
artifact. Gradle runs this plugin on the development computer. Neither is an
application runtime dependency.

The **full Gradle tool distribution is not permissive-only**: upstream's bundled
component inventory also includes EPL, LGPL, CDDL, and MPL licenses. Those build
tool libraries are not copied into this repository or linked into the APK.
The full Android SDK and JDK likewise remain separately installed development
tools; this project does not redistribute them. This distinction is not a
license clearance to incorporate any such library into KeyVox.

This audit covers the initial shell only. It does not cover future runtime
libraries, native bridges, or model assets. The empty runtime dependency graph
is specific to this shell build.
