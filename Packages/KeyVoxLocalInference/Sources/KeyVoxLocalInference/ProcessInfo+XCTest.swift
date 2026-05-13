import Foundation

extension ProcessInfo {
    var isRunningUnderXCTest: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
