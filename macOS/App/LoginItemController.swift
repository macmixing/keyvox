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
            return String(localized: "Login item is unavailable in this build configuration.", comment: "Subtitle of the Launch at Login row in Settings when this build of the app cannot be added as a login item.")
        }
        if requiresApproval {
            return String(localized: "Enabled, but macOS still needs approval in Login Items.", comment: "Subtitle of the Launch at Login row in Settings when macOS still needs the user's approval. Login Items is a page in macOS System Settings; use the name macOS uses in this language.")
        }
        return String(localized: "Start KeyVox automatically when you sign in.", comment: "Subtitle of the Launch at Login row in Settings. KeyVox is a brand name and stays in English.")
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
            errorMessage = String(localized: "Unable to update Launch at Login. You can change this in Login Items.", comment: "Error shown under the Launch at Login row in Settings when the setting cannot be changed. Launch at Login is the row's title; translate it the same way as that title. Login Items is a page in macOS System Settings; use the name macOS uses in this language.")
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
