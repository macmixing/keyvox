# Swift Android runtime notices

This directory retains full upstream notices for the installed Swift 6.3.3
Android SDK used by the arm64 experiment. `provenance.json` records notice URLs
and hashes, installed archive hashes, and the actual speech/Core harness link-map
inventory. `sdk-sbom.spdx.json` is copied verbatim from the installed artifact.

| Runtime family | License coverage |
| --- | --- |
| Swift runtime | Installed Swift Apache-2.0 license with Runtime Library Exception |
| Foundation, CoreFoundation, Swift Foundation | Matching Swift release Apache-2.0 licenses with Runtime Library Exception |
| Foundation Collections | Swift Collections Apache-2.0 with Runtime Library Exception; matching Foundation manifest references 1.1.6 |
| Dispatch / BlocksRuntime | Matching Swift release Apache-2.0 with Runtime Library Exception |
| Foundation ICU | Swift wrapper license plus full ICU 76.1 Unicode/legacy ICU and bundled-data notices |
| Compiler builtins and unwind | Matching Swift LLVM release notices, including LLVM exceptions and legacy terms |
| libxml2 2.11.5 | Full MIT copyright notice |
| curl 8.9.1 | Full curl permissive copying notice |
| BoringSSL fips-20220613 | Full OpenSSL/SSLeay, ISC, and incorporated fiat MIT notices |

The initial speech/Core harness links Swift, Foundation, Collections, ICU, Dispatch,
BlocksRuntime, compiler builtins, and unwind. Networking/XML/SSL libraries are
installed in the SDK but absent from that initial link map. Their notices are retained
for hosts that use those capabilities. NDK `libc++_shared.so` and native Whisper
notices are installed separately by `Tools/build-portable-whisper.sh`.

`networking-link.json` records the later speech harness with its foreground Base
download probe. Its 24 linked SDK archives match the installed hashes in
`provenance.json`, including FoundationNetworking, the URL-session C interface,
curl, and BoringSSL SSL/crypto. The remaining static archives are the existing
Whisper/GGML build. Its ELF dependencies include Android-provided `libz.so` and
`liblog.so`; no zlib runtime or CA certificate bundle is copied into the harness.
`ZLIB-NDK-NOTICE.txt` retains the installed NDK header's permissive zlib notice;
that header is not evidence of the phone's zlib version.

For binaries including BoringSSL, retain these required acknowledgments:

> This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit. (http://www.openssl.org/)

> This product includes cryptographic software written by Eric Young (eay@cryptsoft.com)

Preserve all original naming/nonendorsement and applicable advertising conditions
in `BORINGSSL-LICENSE.txt`. Do not describe it as plain MIT or remove those terms.

## Evidence limits

The official SDK SBOM identifies versions for Swift, libxml2, curl, and BoringSSL
but omits their source commit hashes and some component entries. The installed
ICU header identifies version 76.1. Foundation, Dispatch, compiler-runtime and
ICU-wrapper notices come from the matching Swift release. Collections 1.1.6 is
version evidence from that release's Foundation manifest, not proof of the
SDK builder's exact checkout. Archive hashes identify the actual installed
artifacts; this is not a claim of a reproducible SDK build or a cryptographic
attestation of upstream source-to-binary correspondence.

Full notices preserve incorporated data obligations as well as code licenses.
Include this directory with redistributed binaries; do not apply Swift's runtime
exception to unrelated third-party components.

## Local package test runtime

`testing-runtime.json` records the exact shared-library closure used to execute
existing XCTest suites on Android. XCTest and Swift Testing notices are retained
as `XCTEST-LICENSE.txt` and `TESTING-LICENSE.txt`, both Apache-2.0 with the Swift
Runtime Library Exception. The existing runtime notices above also apply. These
libraries are local test infrastructure; they are not added to the shipping engine
or capture APK. See [test execution and parity results](../../../Docs/Android/TESTING.md).
