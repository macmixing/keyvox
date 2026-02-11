//
//  KeyVoxApp.swift
//  KeyVox
//
//  Created by Dom Esposito on 2/10/26.
//

import SwiftUI
import AVFoundation
import Combine

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
            styleMask: [.fullSizeContentView],
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
        window.center()
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 28
        window.contentView?.layer?.masksToBounds = true
        
        window.contentView = NSHostingView(rootView: OnboardingView(onComplete: {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            window.close()
            self.onboardingWindow = nil
            // Open settings centered immediately after onboarding
            self.openSettings(centered: true)
        }, openSettings: {
            self.openSettings()
        }))
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    func openSettings(centered: Bool = false) {
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
                styleMask: [.fullSizeContentView],
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
            window.hidesOnDeactivate = true
            window.isMovableByWindowBackground = true
            
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 28
            window.contentView?.layer?.masksToBounds = true
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }
        
        // Position logic - Always update position
        if centered {
            window.center()
        } else if let menuBarButton = NSApp.windows.first(where: { $0.className.contains("MenuBar") })?.frame {
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            let xPos = menuBarButton.midX - 250 // Center under icon (250 = half of 500 width)
            let yPos = screenFrame.maxY - 480 // Flush with menu bar bottom edge
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        } else {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct KeyVoxApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var downloader = ModelDownloader.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    init() {
        // App initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                WindowManager.shared.showOnboarding()
            }
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
                openSettings: { WindowManager.shared.openSettings() },
                quitApp: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            menuBarImage
        }
        .menuBarExtraStyle(.window)
        .onChange(of: hasCompletedOnboarding) {
            // Re-evaluates state
        }
    }
}
