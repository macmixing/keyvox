import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var isUpdating: Bool = false
    @Published private(set) var requiresApproval: Bool = false
    @Published private(set) var isUnavailable: Bool = false
    @Published var errorMessage: String?

    var subtitle: String {
        if isUnavailable {
            return "Login item is unavailable in this build configuration."
        }
        if requiresApproval {
            return "Enabled, but macOS still needs approval in Login Items."
        }
        return "Start KeyVox automatically when you sign in."
    }

    var shouldShowOpenSystemSettingsAction: Bool {
        requiresApproval || errorMessage != nil
    }

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        apply(status: SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        guard enabled != isEnabled || (enabled && requiresApproval) else { return }

        isUpdating = true
        errorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            refreshStatus()
            errorMessage = "Unable to update Launch at Login. You can change this in Login Items."
            #if DEBUG
            print("LoginItemController: failed to update login item state: \(error.localizedDescription)")
            #endif
        }

        isUpdating = false
    }

    func openLoginItemsSettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }

    private func apply(status: SMAppService.Status) {
        switch status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
            isUnavailable = false
        case .requiresApproval:
            isEnabled = true
            requiresApproval = true
            isUnavailable = false
        case .notRegistered:
            isEnabled = false
            requiresApproval = false
            isUnavailable = false
        case .notFound:
            isEnabled = false
            requiresApproval = false
            isUnavailable = true
        @unknown default:
            isEnabled = false
            requiresApproval = false
            isUnavailable = true
        }
    }
}
