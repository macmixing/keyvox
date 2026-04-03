import Foundation

enum KeyVoxIPCLiveMeterSignalState: UInt8, Equatable {
    case dead = 0
    case quiet = 1
    case active = 2
}

struct KeyVoxIPCLiveMeterSnapshot: Equatable {
    let level: Float
    let signalState: KeyVoxIPCLiveMeterSignalState
    let sequence: UInt32
    let timestamp: TimeInterval
}

enum KeyVoxTTSState: String, Codable, Equatable {
    case idle
    case preparing
    case generating
    case playing
    case finished
    case error
}

enum KeyVoxTTSRequestSourceSurface: String, Codable, Equatable {
    case keyboard
    case app
}

enum KeyVoxTTSRequestKind: String, Codable, Equatable {
    case speakClipboardText
}

struct KeyVoxTTSRequest: Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: TimeInterval
    let sourceSurface: KeyVoxTTSRequestSourceSurface
    let voiceID: String
    let kind: KeyVoxTTSRequestKind

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum KeyVoxIPCBridge {
    static let appGroupID = "group.com.cueit.keyvox"
    static let keyboardBundleIdentifier = "com.cueit.keyvox.ios.keyboard"
    
    // MARK: - Keys
    enum Key {
        static let recordingState = "recordingState"
        static let recordingStateTimestamp = "recordingState_timestamp"
        static let transcription = "latestTranscription"
        static let sessionTimestamp = "session_timestamp"
        static let sessionHasBluetoothAudioRoute = "sessionHasBluetoothAudioRoute"
        static let recentTTSPlaybackTimestamp = "recentTTSPlayback_timestamp"
        static let ttsState = "ttsState"
        static let ttsStateTimestamp = "ttsState_timestamp"
        static let ttsErrorMessage = "ttsErrorMessage"
        static let ttsPlaybackMeterLevel = "ttsPlaybackMeterLevel"
        static let ttsPlaybackMeterSignalState = "ttsPlaybackMeterSignalState"
        static let ttsPlaybackMeterTimestamp = "ttsPlaybackMeterTimestamp"
        static let keyboardOnboardingPresentationTimestamp = "keyboardOnboardingPresentation_timestamp"
        static let keyboardOnboardingAccessTimestamp = "keyboardOnboardingAccess_timestamp"
        static let keyboardOnboardingHasFullAccess = "keyboardOnboardingHasFullAccess"
    }

    private enum LiveMeterPacket {
        static let version: UInt8 = 1
        static let byteCount = 20
        static let fileName = "live-meter-state.bin"
    }
    
    // MARK: - Notifications
    enum Notification {
        static let startRecording = "com.cueit.keyvox.startRecording"
        static let stopRecording = "com.cueit.keyvox.stopRecording"
        static let cancelRecording = "com.cueit.keyvox.cancelRecording"
        static let disableSession = "com.cueit.keyvox.disableSession"
        static let recordingStarted = "com.cueit.keyvox.recordingStarted"
        static let transcribingStarted = "com.cueit.keyvox.transcribingStarted"
        static let transcriptionReady = "com.cueit.keyvox.transcriptionReady"
        static let noSpeech = "com.cueit.keyvox.noSpeech"
        static let startTTS = "com.cueit.keyvox.startTTS"
        static let stopTTS = "com.cueit.keyvox.stopTTS"
        static let ttsPreparing = "com.cueit.keyvox.ttsPreparing"
        static let ttsPlaying = "com.cueit.keyvox.ttsPlaying"
        static let ttsFinished = "com.cueit.keyvox.ttsFinished"
        static let ttsFailed = "com.cueit.keyvox.ttsFailed"
    }
    
    static let heartbeatFreshnessWindow: TimeInterval = 5 // 5 seconds (active heartbeat is 1Hz)
    static let recentTTSWarmStartWindow: TimeInterval = 8
    
    private static var defaults: UserDefaults? {
        let d = UserDefaults(suiteName: appGroupID)
        return d
    }

    private static let liveMeterLock = NSLock()
    private static var liveMeterSequence: UInt32 = 0
    
    // MARK: - Write (Main App)
    
    static func setSessionActive() {
        let d = defaults
        let timestamp = Date().timeIntervalSince1970
        d?.set(timestamp, forKey: Key.sessionTimestamp)
        NSLog("[KeyVoxIPCBridge] setSessionActive ts=%.3f", timestamp)
    }

    static func setSessionHasBluetoothAudioRoute(_ hasBluetoothAudioRoute: Bool) {
        defaults?.set(hasBluetoothAudioRoute, forKey: Key.sessionHasBluetoothAudioRoute)
    }

    static func clearSessionActive() {
        let d = defaults
        d?.removeObject(forKey: Key.sessionTimestamp)
        d?.removeObject(forKey: Key.sessionHasBluetoothAudioRoute)
        NSLog("[KeyVoxIPCBridge] clearSessionActive")
    }
    
    static func setRecordingState(_ state: String) {
        let d = defaults
        d?.set(state, forKey: Key.recordingState)
        d?.set(Date().timeIntervalSince1970, forKey: Key.recordingStateTimestamp)
        
    }
    
    static func setTranscription(_ text: String) {
        let d = defaults
        d?.set(text, forKey: Key.transcription)
        
    }
    
    static func removeTranscription() {
        let d = defaults
        d?.removeObject(forKey: Key.transcription)
        
    }

    static func clearTransientOperationState() {
        let d = defaults
        d?.removeObject(forKey: Key.recordingState)
        d?.removeObject(forKey: Key.recordingStateTimestamp)
        clearLiveMeter()
    }

    static func setTTSState(_ state: KeyVoxTTSState, errorMessage: String? = nil) {
        defaults?.set(state.rawValue, forKey: Key.ttsState)
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.ttsStateTimestamp)

        if let errorMessage, !errorMessage.isEmpty {
            defaults?.set(errorMessage, forKey: Key.ttsErrorMessage)
        } else {
            defaults?.removeObject(forKey: Key.ttsErrorMessage)
        }
    }

    static func clearTTSState() {
        defaults?.removeObject(forKey: Key.ttsState)
        defaults?.removeObject(forKey: Key.ttsStateTimestamp)
        defaults?.removeObject(forKey: Key.ttsErrorMessage)
        clearTTSPlaybackMeter()
    }

    static func markRecentTTSPlayback() {
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.recentTTSPlaybackTimestamp)
    }

    static func clearRecentTTSPlayback() {
        defaults?.removeObject(forKey: Key.recentTTSPlaybackTimestamp)
    }

    static func writeTTSRequest(_ request: KeyVoxTTSRequest, fileManager: FileManager = .default) {
        guard let requestURL = ttsRequestURL(fileManager: fileManager) else { return }
        try? fileManager.createDirectory(
            at: requestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard let data = try? JSONEncoder().encode(request) else { return }
        try? data.write(to: requestURL, options: .atomic)
    }

    static func readTTSRequest(fileManager: FileManager = .default) -> KeyVoxTTSRequest? {
        guard let requestURL = ttsRequestURL(fileManager: fileManager),
              let data = try? Data(contentsOf: requestURL) else {
            return nil
        }

        return try? JSONDecoder().decode(KeyVoxTTSRequest.self, from: data)
    }

    static func clearTTSRequest(fileManager: FileManager = .default) {
        guard let requestURL = ttsRequestURL(fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: requestURL)
    }

    static func writeLiveMeter(level: Float, signalState: KeyVoxIPCLiveMeterSignalState) {
        guard let url = liveMeterFileURL() else { return }

        liveMeterLock.lock()
        liveMeterSequence &+= 1
        let sequence = liveMeterSequence
        liveMeterLock.unlock()

        var data = Data(capacity: LiveMeterPacket.byteCount)
        data.append(LiveMeterPacket.version)
        data.append(signalState.rawValue)
        append(UInt16.zero, to: &data)
        append(level.bitPattern, to: &data)
        append(sequence, to: &data)
        append(Date().timeIntervalSince1970.bitPattern, to: &data)

        try? data.write(to: url, options: .atomic)
    }

    static func clearLiveMeter() {
        guard let url = liveMeterFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func writeTTSPlaybackMeter(level: Float, signalState: KeyVoxIPCLiveMeterSignalState) {
        defaults?.set(level, forKey: Key.ttsPlaybackMeterLevel)
        defaults?.set(signalState.rawValue, forKey: Key.ttsPlaybackMeterSignalState)
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.ttsPlaybackMeterTimestamp)
    }

    static func currentTTSPlaybackMeterSnapshot() -> KeyVoxIPCLiveMeterSnapshot? {
        guard let level = defaults?.object(forKey: Key.ttsPlaybackMeterLevel) as? Float,
              let signalStateRawValue = defaults?.object(forKey: Key.ttsPlaybackMeterSignalState) as? UInt8,
              let signalState = KeyVoxIPCLiveMeterSignalState(rawValue: signalStateRawValue),
              let timestamp = defaults?.object(forKey: Key.ttsPlaybackMeterTimestamp) as? TimeInterval else {
            return nil
        }

        return KeyVoxIPCLiveMeterSnapshot(
            level: level,
            signalState: signalState,
            sequence: 0,
            timestamp: timestamp
        )
    }

    static func clearTTSPlaybackMeter() {
        defaults?.removeObject(forKey: Key.ttsPlaybackMeterLevel)
        defaults?.removeObject(forKey: Key.ttsPlaybackMeterSignalState)
        defaults?.removeObject(forKey: Key.ttsPlaybackMeterTimestamp)
    }
    
    private static var lastHeartbeatUpdateTime: TimeInterval = 0

    private static func ttsRequestURL(fileManager: FileManager) -> URL? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        return containerURL
            .appendingPathComponent("TTS", isDirectory: true)
            .appendingPathComponent("request.json", isDirectory: false)
    }
    
    static func touchHeartbeat() {
        let now = Date().timeIntervalSince1970
        // Limit frequency to ~1Hz to avoid UserDefaults thrashing
        guard now - lastHeartbeatUpdateTime >= 1.0 else { return }
        lastHeartbeatUpdateTime = now
        
        let d = defaults
        d?.set(now, forKey: Key.sessionTimestamp)
        
    }

    static func reportKeyboardOnboardingState(hasFullAccess: Bool) {
        let now = Date().timeIntervalSince1970
        defaults?.set(hasFullAccess, forKey: Key.keyboardOnboardingHasFullAccess)

        if hasFullAccess {
            defaults?.set(now, forKey: Key.keyboardOnboardingAccessTimestamp)
        }
    }

    static func reportKeyboardOnboardingPresentation() {
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.keyboardOnboardingPresentationTimestamp)
    }

    static func clearKeyboardOnboardingPresentation() {
        defaults?.removeObject(forKey: Key.keyboardOnboardingPresentationTimestamp)
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

    static func sessionHasBluetoothAudioRoute() -> Bool {
        defaults?.object(forKey: Key.sessionHasBluetoothAudioRoute) as? Bool ?? false
    }

    static func currentRecordingStateAge() -> TimeInterval? {
        guard let d = defaults else { return nil }
        let ts = d.double(forKey: Key.recordingStateTimestamp)
        guard ts > 0 else { return nil }
        return Date().timeIntervalSince1970 - ts
    }
    
    static func latestTranscription() -> String? {
        let d = defaults
        
        return d?.string(forKey: Key.transcription)
    }

    static func currentTTSState() -> KeyVoxTTSState {
        guard let rawValue = defaults?.string(forKey: Key.ttsState),
              let state = KeyVoxTTSState(rawValue: rawValue) else {
            return .idle
        }

        return state
    }

    static func currentTTSStateAge() -> TimeInterval? {
        guard let timestamp = defaults?.object(forKey: Key.ttsStateTimestamp) as? TimeInterval else {
            return nil
        }

        return Date().timeIntervalSince1970 - timestamp
    }

    static func hadRecentTTSPlayback() -> Bool {
        guard let timestamp = defaults?.object(forKey: Key.recentTTSPlaybackTimestamp) as? TimeInterval else {
            return false
        }

        return Date().timeIntervalSince1970 - timestamp < recentTTSWarmStartWindow
    }

    static func currentTTSErrorMessage() -> String? {
        defaults?.string(forKey: Key.ttsErrorMessage)
    }

    static func keyboardOnboardingAccessTimestamp() -> TimeInterval? {
        guard let d = defaults else { return nil }

        let timestamp = d.double(forKey: Key.keyboardOnboardingAccessTimestamp)
        guard timestamp.isFinite, timestamp > 0 else {
            return nil
        }

        return timestamp
    }

    static func keyboardOnboardingPresentationTimestamp() -> TimeInterval? {
        guard let d = defaults else { return nil }

        let timestamp = d.double(forKey: Key.keyboardOnboardingPresentationTimestamp)
        guard timestamp.isFinite, timestamp > 0 else {
            return nil
        }

        return timestamp
    }

    static func keyboardOnboardingHasFullAccess() -> Bool {
        defaults?.object(forKey: Key.keyboardOnboardingHasFullAccess) as? Bool ?? false
    }

    static func currentLiveMeterSnapshot() -> KeyVoxIPCLiveMeterSnapshot? {
        guard let url = liveMeterFileURL(),
              let data = try? Data(contentsOf: url),
              data.count == LiveMeterPacket.byteCount else {
            return nil
        }

        var offset = 0
        guard let version = read(UInt8.self, from: data, at: &offset),
              version == LiveMeterPacket.version,
              let rawSignalState = read(UInt8.self, from: data, at: &offset),
              let signalState = KeyVoxIPCLiveMeterSignalState(rawValue: rawSignalState) else {
            return nil
        }

        offset += MemoryLayout<UInt16>.size

        guard let levelBits = read(UInt32.self, from: data, at: &offset),
              let sequence = read(UInt32.self, from: data, at: &offset),
              let timestampBits = read(UInt64.self, from: data, at: &offset) else {
            return nil
        }

        return KeyVoxIPCLiveMeterSnapshot(
            level: Float(bitPattern: levelBits),
            signalState: signalState,
            sequence: sequence,
            timestamp: Double(bitPattern: timestampBits)
        )
    }

    private static func liveMeterFileURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(LiveMeterPacket.fileName, isDirectory: false)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private static func read<T: FixedWidthInteger>(_ type: T.Type, from data: Data, at offset: inout Int) -> T? {
        let endOffset = offset + MemoryLayout<T>.size
        guard endOffset <= data.count else { return nil }

        var value: T = 0
        _ = withUnsafeMutableBytes(of: &value) { buffer in
            data.copyBytes(to: buffer, from: offset..<endOffset)
        }
        offset = endOffset
        return T(littleEndian: value)
    }
}
