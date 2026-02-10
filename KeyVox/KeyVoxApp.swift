//
//  KeyVoxApp.swift
//  KeyVox
//
//  Created by Dom Esposito on 2/10/26.
//

import SwiftUI

@main
struct KeyVoxApp: App {
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var downloader = ModelDownloader()
    
    var body: some Scene {
        MenuBarExtra("KeyVox", systemImage: transcriptionManager.state == .recording ? "waveform.circle.fill" : "waveform.circle") {
            VStack {
                Text("KeyVox Status: \(statusText)")
                if !downloader.isModelDownloaded {
                    Text("⚠️ Model missing")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if !AXIsProcessTrusted() {
                    Text("⚠️ Accessibility Permission Required")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Grant Permission...") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                        AXIsProcessTrustedWithOptions(options as CFDictionary)
                    }
                }
                Divider()
                Button("Settings") {
                    openSettings()
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    
    private var statusText: String {
        switch transcriptionManager.state {
        case .idle: return "Idle"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    @State private var settingsWindow: NSWindow?
    
    private func openSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false // Critical for manual lifecycle management
        window.center()
        window.setFrameAutosaveName("Settings")
        window.title = "KeyVox Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
