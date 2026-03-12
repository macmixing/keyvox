//
//  KeyVoxApp.swift
//  KeyVox
//
//  Created by Dom Esposito on 2/10/26.
//

import SwiftUI
import AVFoundation
import Combine

final class KeyVoxAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            if AppSettingsStore.shared.hasCompletedOnboarding {
                WindowManager.shared.openSettings(centered: true)
            } else {
                WindowManager.shared.showOnboarding()
            }
        }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let settingsWindow = WindowManager.shared.settingsWindow,
           settingsWindow.isVisible,
           sender.isActive,
           (settingsWindow.isKeyWindow || settingsWindow.isMainWindow) {
            // Intentional: first quit closes Settings instead of terminating, so
            // users don't accidentally exit KeyVox while actively editing settings.
            settingsWindow.orderOut(nil)
            return .terminateCancel
        }

        return .terminateNow
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var settingsWindow: NSWindow?
    @Published var onboardingWindow: NSWindow?
    @Published var updateWindow: NSWindow?
    @Published var postUpdateNoticeWindow: NSWindow?
    
    private init() {} // Private init for singleton
    
    @MainActor
    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingSize = OnboardingView.preferredWindowSize
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: onboardingSize.width, height: onboardingSize.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.center()
        
        
        window.contentView = NSHostingView(rootView: OnboardingView(onComplete: {
            AppSettingsStore.shared.hasCompletedOnboarding = true
            window.close()
            self.onboardingWindow = nil
            // Open settings centered immediately after onboarding
            self.openSettings(centered: true)
        }, openSettings: {
            self.openSettings()
        }, beginMicrophoneAuthorization: {
            self.lowerOnboardingWindowForMicrophoneAuthorization()
        }, beginAccessibilityAuthorization: {
            self.lowerOnboardingWindowForAccessibilityPrompt()
        }, endAccessibilityAuthorization: {
            self.restoreOnboardingWindowAfterAccessibilityGranted()
        }, onPreferredHeightChange: { [weak window] height in
            guard let window else { return }
            let targetSize = CGSize(width: OnboardingView.preferredWindowSize.width, height: height)
            if window.contentLayoutRect.size != targetSize {
                window.setContentSize(targetSize)
            }
        }))

        window.setContentSize(onboardingSize)
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func lowerOnboardingWindowForAccessibilityPrompt() {
        onboardingWindow?.level = .normal
    }

    @MainActor
    func lowerOnboardingWindowForMicrophoneAuthorization() {
        onboardingWindow?.level = .normal
    }

    @MainActor
    func restoreOnboardingWindowAfterAccessibilityGranted() {
        guard let onboardingWindow else { return }
        onboardingWindow.level = .floating
        onboardingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func openSettings(centered: Bool = true, tab: SettingsTab? = nil) {
        let settingsSize = SettingsView.preferredWindowSize
        let isNewWindow = (settingsWindow == nil)

        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: settingsSize.width, height: settingsSize.height),
                styleMask: [.titled, .fullSizeContentView, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .normal
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = true

            window.contentView = NSHostingView(rootView: SettingsView(initialTab: tab ?? .general))
            self.settingsWindow = window
        }

        if !isNewWindow, let requestedTab = tab {
            // Only rebuild settings content when the caller explicitly requests a tab.
            // This preserves the user's current tab selection for passive reopen flows (e.g. Dock click).
            window.contentView = NSHostingView(rootView: SettingsView(initialTab: requestedTab))
        }

        window.setContentSize(settingsSize)
        window.level = .normal
        
        if centered {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
@main
struct KeyVoxApp: App {
    @NSApplicationDelegateAdaptor(KeyVoxAppDelegate.self) private var appDelegate
    @StateObject private var transcriptionManager = TranscriptionManager()
    @ObservedObject private var appSettings = AppSettingsStore.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var downloader = ModelDownloader.shared
    @ObservedObject private var updateCoordinator = AppUpdateCoordinator.shared
    private let appServiceRegistry = AppServiceRegistry.shared
    private let onboardingStartupDelay: TimeInterval = 0.1

    nonisolated static func shouldUseAccessoryActivationPolicy(
        osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> Bool {
        if osVersion.majorVersion < 15 {
            return true
        }
        if osVersion.majorVersion > 15 {
            return false
        }
        return osVersion.minorVersion < 6
    }
    
    init() {
        // Fix for Ventura/Sonoma < 15.6 menu bar collision and event blocking.
        if Self.shouldUseAccessoryActivationPolicy() {
            // Switch to accessory policy for older OS versions to prevent
            // the status item from blocking the Apple Logo.
            NSApplication.shared.setActivationPolicy(.accessory)
        }

        // App initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + onboardingStartupDelay) {
            if !AppSettingsStore.shared.hasCompletedOnboarding {
                WindowManager.shared.showOnboarding()
            }
        }

        Task { @MainActor in
            AppUpdateCoordinator.shared.prepareForLaunch()
            AppUpdateService.shared.startUpdateTimer()
            if AppUpdateCoordinator.shared.postUpdateNoticeVersion != nil {
                WindowManager.shared.showPostUpdateNoticeWindow()
            }
        }

        _ = appServiceRegistry.iCloudSyncCoordinator
    }
    
    private var menuBarImage: Image {
        let imageName = transcriptionManager.state == .recording ? "logo-white-invert" : "logo-white"
        if let nsImage = NSImage(named: imageName) {
            nsImage.isTemplate = true
            nsImage.size = NSSize(width: 18, height: 18)
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "waveform.circle")
    }
    
    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(
                manager: transcriptionManager,
                openSettings: { tab in WindowManager.shared.openSettings(tab: tab) },
                checkForUpdates: { AppUpdateCoordinator.shared.openWindowForManualCheck() },
                quitApp: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            menuBarImage
        }
        .menuBarExtraStyle(.window)
        .onChange(of: appSettings.hasCompletedOnboarding) { _ in
            // Re-evaluates state
        }
    }
}
