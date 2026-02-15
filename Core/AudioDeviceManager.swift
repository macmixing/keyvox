import Foundation
import Combine
import AVFoundation
import CoreAudio

enum MicrophoneKind {
    case builtIn
    case airPods
    case bluetooth
    case wiredOrOther
}

struct MicrophoneOption: Identifiable, Equatable {
    let id: String // AVCaptureDevice.uniqueID
    let name: String
    let kind: MicrophoneKind
    let isAvailable: Bool
}

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    @Published private(set) var availableMicrophones: [MicrophoneOption] = []
    @Published var selectedMicrophoneUID: String {
        didSet {
            UserDefaults.standard.set(selectedMicrophoneUID, forKey: UserDefaultsKeys.selectedMicrophoneUID)
            syncSelectedMicrophone()
        }
    }
    @Published private(set) var selectedMicrophone: MicrophoneOption?

    private var deviceObservers: [NSObjectProtocol] = []

    private init() {
        selectedMicrophoneUID = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""

        availableMicrophones = Self.discoverInputMicrophones()
        applyInitialSelectionPolicy()
        syncSelectedMicrophone()
        startMonitoringCaptureDevices()
    }

    deinit {
        for observer in deviceObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var pickerMicrophones: [MicrophoneOption] {
        guard !selectedMicrophoneUID.isEmpty,
              selectedMicrophone == nil,
              !availableMicrophones.contains(where: { $0.id == selectedMicrophoneUID }) else {
            return availableMicrophones
        }

        let unavailable = MicrophoneOption(
            id: selectedMicrophoneUID,
            name: "Previously Selected Microphone (Unavailable)",
            kind: .wiredOrOther,
            isAvailable: false
        )
        return availableMicrophones + [unavailable]
    }

    func resolvedCaptureDevice() -> AVCaptureDevice? {
        if let selected = selectedMicrophone,
           let selectedDevice = deviceForID(selected.id) {
            return selectedDevice
        }

        if !selectedMicrophoneUID.isEmpty,
           let selectedFromUID = deviceForID(selectedMicrophoneUID) {
            return selectedFromUID
        }

        return builtInCaptureDevice() ?? AVCaptureDevice.default(for: .audio) ?? Self.captureAudioDevices().first
    }

    func builtInCaptureDevice() -> AVCaptureDevice? {
        if let builtInID = builtInMicrophone?.id,
           let device = deviceForID(builtInID) {
            return device
        }

        return Self.captureAudioDevices().first {
            Self.classifyDeviceKind(for: $0) == .builtIn
        }
    }

    func refreshAvailableMicrophones() {
        let discovered = Self.discoverInputMicrophones()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.availableMicrophones = discovered
            self.syncSelectedMicrophone()
        }
    }

    private var builtInMicrophone: MicrophoneOption? {
        availableMicrophones.first(where: { $0.kind == .builtIn && $0.isAvailable })
    }

    private func applyInitialSelectionPolicy() {
        let defaults = UserDefaults.standard
        let hasInitialized = defaults.bool(forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)

        if !hasInitialized {
            if let builtInMicrophone {
                selectedMicrophoneUID = builtInMicrophone.id
            } else if let first = availableMicrophones.first {
                selectedMicrophoneUID = first.id
            }

            defaults.set(true, forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)
            return
        }

        if selectedMicrophoneUID.isEmpty, let builtInMicrophone {
            selectedMicrophoneUID = builtInMicrophone.id
        }
    }

    private func syncSelectedMicrophone() {
        selectedMicrophone = availableMicrophones.first(where: { $0.id == selectedMicrophoneUID })
    }

    private func startMonitoringCaptureDevices() {
        let connectedObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableMicrophones()
        }

        let disconnectedObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableMicrophones()
        }

        deviceObservers = [connectedObserver, disconnectedObserver]
    }

    private func deviceForID(_ uniqueID: String) -> AVCaptureDevice? {
        Self.captureAudioDevices().first(where: { $0.uniqueID == uniqueID })
    }

    nonisolated private static func discoverInputMicrophones() -> [MicrophoneOption] {
        captureAudioDevices()
            .map { device in
                MicrophoneOption(
                    id: device.uniqueID,
                    name: device.localizedName,
                    kind: classifyDeviceKind(for: device),
                    isAvailable: true
                )
            }
            .sorted(by: microphoneSortPredicate)
    }

    nonisolated private static func captureAudioDevices() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices
    }

    nonisolated private static func microphoneSortPredicate(_ lhs: MicrophoneOption, _ rhs: MicrophoneOption) -> Bool {
        let lhsRank = sortRank(for: lhs.kind)
        let rhsRank = sortRank(for: rhs.kind)

        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    nonisolated private static func sortRank(for kind: MicrophoneKind) -> Int {
        switch kind {
        case .builtIn:
            return 0
        case .wiredOrOther:
            return 1
        case .airPods:
            return 2
        case .bluetooth:
            return 3
        }
    }

    nonisolated private static func classifyDeviceKind(for device: AVCaptureDevice) -> MicrophoneKind {
        let lowered = device.localizedName.lowercased()

        if lowered.contains("airpods") {
            return .airPods
        }

        let transportType = UInt32(bitPattern: device.transportType)
        if transportType == kAudioDeviceTransportTypeBluetooth ||
            transportType == kAudioDeviceTransportTypeBluetoothLE {
            return .bluetooth
        }

        if transportType == kAudioDeviceTransportTypeBuiltIn {
            return .builtIn
        }

        if lowered.contains("bluetooth") ||
            lowered.contains("hands-free") ||
            lowered.contains("headset") ||
            lowered.contains("earbuds") ||
            lowered.contains("buds") {
            return .bluetooth
        }

        if lowered.contains("built-in") ||
            lowered.contains("built in") ||
            lowered.contains("internal") {
            return .builtIn
        }

        return .wiredOrOther
    }
}
