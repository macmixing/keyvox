import AVFoundation
import Testing
@testable import KeyVox_iOS

struct AudioBluetoothRoutePolicyTests {
    @Test func usesA2DPFamilyWhenBuiltInMicrophoneIsPreferred() {
        let policy = AudioBluetoothRoutePolicy(preferBuiltInMicrophone: true)

        #expect(policy.family == .builtInMicWithBluetoothPlayback)
        #expect(policy.bluetoothCategoryOptions.contains(.allowBluetoothA2DP))
        #expect(!policy.bluetoothCategoryOptions.contains(.allowBluetoothHFP))
    }

    @Test func usesBidirectionalHFPFamilyWhenBuiltInMicrophoneIsDisabled() {
        let policy = AudioBluetoothRoutePolicy(preferBuiltInMicrophone: false)

        #expect(policy.family == .bluetoothHFPBidirectional)
        #expect(policy.bluetoothCategoryOptions.contains(.allowBluetoothHFP))
        #expect(!policy.bluetoothCategoryOptions.contains(.allowBluetoothA2DP))
    }
}
