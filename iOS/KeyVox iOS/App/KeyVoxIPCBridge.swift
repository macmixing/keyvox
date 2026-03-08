import Foundation

enum KeyVoxIPCBridge {
    static let appGroupID = "group.com.cueit.keyvox"
    
    // MARK: - Keys
    enum Key {
        static let recordingState = "recordingState"
        static let transcription = "latestTranscription"
        static let sessionTimestamp = "session_timestamp"
    }
    
    // MARK: - Notifications
    enum Notification {
        static let startRecording = "com.cueit.keyvox.startRecording"
        static let stopRecording = "com.cueit.keyvox.stopRecording"
        static let recordingStarted = "com.cueit.keyvox.recordingStarted"
        static let transcriptionReady = "com.cueit.keyvox.transcriptionReady"
        static let noSpeech = "com.cueit.keyvox.noSpeech"
    }
    
    static let heartbeatFreshnessWindow: TimeInterval = 5 // 5 seconds (active heartbeat is 1Hz)
    
    private static var defaults: UserDefaults? {
        let d = UserDefaults(suiteName: appGroupID)
        return d
    }
    
    // MARK: - Write (Main App)
    
    static func setSessionActive() {
        let d = defaults
        d?.set(Date().timeIntervalSince1970, forKey: Key.sessionTimestamp)
    }

    static func clearSessionActive() {
        let d = defaults
        d?.removeObject(forKey: Key.sessionTimestamp)
    }
    
    static func setRecordingState(_ state: String) {
        let d = defaults
        d?.set(state, forKey: Key.recordingState)
        
    }
    
    static func setTranscription(_ text: String) {
        let d = defaults
        d?.set(text, forKey: Key.transcription)
        
    }
    
    static func removeTranscription() {
        let d = defaults
        d?.removeObject(forKey: Key.transcription)
        
    }
    
    private static var lastHeartbeatUpdateTime: TimeInterval = 0
    
    static func touchHeartbeat() {
        let now = Date().timeIntervalSince1970
        // Limit frequency to ~1Hz to avoid UserDefaults thrashing
        guard now - lastHeartbeatUpdateTime >= 1.0 else { return }
        lastHeartbeatUpdateTime = now
        
        let d = defaults
        d?.set(now, forKey: Key.sessionTimestamp)
        
    }
    
    // MARK: - Read (Both)
    
    static func isSessionWarm() -> Bool {
        guard let d = defaults else { return false }        
        let ts = d.double(forKey: Key.sessionTimestamp)
        guard ts > 0 else { return false }
        
        return Date().timeIntervalSince1970 - ts < heartbeatFreshnessWindow
    }
    
    static func currentRecordingState() -> String? {
        let d = defaults
        
        return d?.string(forKey: Key.recordingState)
    }
    
    static func latestTranscription() -> String? {
        let d = defaults
        
        return d?.string(forKey: Key.transcription)
    }
}
