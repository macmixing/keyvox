import AVFoundation
import Foundation

struct AudioBluetoothRoutePolicy {
    enum Family: String {
        case builtInMicWithBluetoothPlayback = "builtInMicWithBluetoothPlayback"
        case bluetoothHFPBidirectional = "bluetoothHFPBidirectional"
    }

    let family: Family

    init(preferBuiltInMicrophone: Bool) {
        family = preferBuiltInMicrophone
            ? .builtInMicWithBluetoothPlayback
            : .bluetoothHFPBidirectional
    }

    var bluetoothCategoryOptions: AVAudioSession.CategoryOptions {
        switch family {
        case .builtInMicWithBluetoothPlayback:
            return [.allowBluetoothA2DP]
        case .bluetoothHFPBidirectional:
            return [.allowBluetoothHFP]
        }
    }
}
