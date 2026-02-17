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
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var settingsWindow: NSWindow?
    @Published var onboardingWindow: NSWindow?
    
    private init() {} // Private init for singleton
    
    @MainActor
    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
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
        }))
        
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
    func openSettings(centered: Bool = true, tab: SettingsTab = .general) {
        let settingsSize = SettingsView.preferredWindowSize

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
            window.level = .floating
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = true

            window.contentView = NSHostingView(rootView: SettingsView(initialTab: tab))
            self.settingsWindow = window
        }

        window.setContentSize(settingsSize)
        window.contentView = NSHostingView(rootView: SettingsView(initialTab: tab))
        
        if centered {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct KeyVoxApp: App {
    @NSApplicationDelegateAdaptor(KeyVoxAppDelegate.self) private var appDelegate
    @StateObject private var transcriptionManager = TranscriptionManager()
    @ObservedObject private var appSettings = AppSettingsStore.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var downloader = ModelDownloader.shared
    private let onboardingStartupDelay: TimeInterval = 0.1

    static func shouldUseAccessoryActivationPolicy(
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
            AppUpdateService.shared.startUpdateTimer()
        }
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
                checkForUpdates: { AppUpdateService.shared.checkForUpdatesManually() },
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
