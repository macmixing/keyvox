# KeyVoxState

Main-actor state publication without choosing a frontend. State owners keep their
existing access control and expose updates through `@StateValue`.

On Apple, `StateValue` and `StatePublishing` are exact aliases for the existing
Combine types, preserving projected publishers and automatic object observation.
On other platforms, the projection exposes read-only current state and an
`AsyncStream` through `.values`. Each subscriber has an independent buffer of one
latest value. This is state observation, not a lossless event log.

`StateChannel` owns a portable current value; `StateUpdates` gives observers
read-only access. Stream cancellation removes its subscriber, and channel
destruction finishes remaining streams. The library contains no UI types.

## Verification

The Mac test suite and Android executable run the same framework-independent
checks for initial state, multicast updates, bounded buffering, destruction,
cancellation isolation, and property-wrapper publication. Apple additionally
checks projected Combine values and object-change notifications.

```sh
cd Packages/KeyVoxState
swift build --product StateProbe \
  --swift-sdk aarch64-unknown-linux-android28 \
  --static-swift-stdlib \
  --scratch-path /tmp/keyvox-port-state-probe-android
```

Deploy `StateProbe` from the build output to the Android device and execute it.
The installed Android SDK does not include XCTest or Swift Testing, so this
probe runs the shared checks without either testing framework. The probe imports
Dispatch to link the static concurrency executor; the state library itself uses
portable Swift concurrency.

Android status: **FUNCTIONAL**. The probe passed on the connected arm64 device.
KeyVoxPromotions also compiles with this boundary. Windows and Linux can use the
same non-Combine implementation; their execution remains unverified.
