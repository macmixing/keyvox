import Foundation

/// The hardware model identifier of the device the keyboard runs on. The simulator reports the
/// model it simulates rather than the Mac's architecture.
enum KeyboardDeviceModel {
    static let identifier: String = {
        if let simulatedIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatedIdentifier
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()
}
