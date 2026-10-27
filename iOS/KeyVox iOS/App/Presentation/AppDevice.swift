import UIKit

/// The kind of device KeyVox runs on, for the layout and copy that differ on iPad.
enum AppDevice {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
