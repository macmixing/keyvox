import AVFoundation
import Combine
import Foundation

enum iOSOnboardingMicrophonePermissionStatus: Equatable {
    case undetermined
    case denied
    case granted
}

@MainActor
final class iOSOnboardingMicrophonePermissionController: ObservableObject {
    typealias StatusProvider = @MainActor () -> iOSOnboardingMicrophonePermissionStatus
    typealias PermissionRequester = @MainActor () async -> Bool

    @Published private(set) var status: iOSOnboardingMicrophonePermissionStatus

    private let statusProvider: StatusProvider
    private let requestPermissionHandler: PermissionRequester

    init(
        statusProvider: StatusProvider? = nil,
        requestPermissionHandler: PermissionRequester? = nil
    ) {
        let resolvedStatusProvider = statusProvider ?? { Self.defaultStatusProvider() }
        let resolvedRequestPermissionHandler = requestPermissionHandler ?? { await Self.defaultRequestPermissionHandler() }

        self.statusProvider = resolvedStatusProvider
        self.requestPermissionHandler = resolvedRequestPermissionHandler
        status = resolvedStatusProvider()
    }

    func refreshStatus() {
        status = statusProvider()
    }

    func requestPermission() async {
        _ = await requestPermissionHandler()
        refreshStatus()
    }

    private static func defaultStatusProvider() -> iOSOnboardingMicrophonePermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            return .undetermined
        case .denied:
            return .denied
        case .granted:
            return .granted
        @unknown default:
            return .denied
        }
    }

    private static func defaultRequestPermissionHandler() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
