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

struct AudioDeviceClassificationInput {
    let name: String
    let transportType: UInt32
}

protocol AudioDeviceSettingsStoring: AnyObject {
    var selectedMicrophoneUID: String { get set }
    var selectedMicrophoneUIDPublisher: AnyPublisher<String, Never> { get }
}

final class AppSettingsAudioDeviceStore: AudioDeviceSettingsStoring {
    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<String, Never>
    private let notificationCenter: NotificationCenter
    private var defaultsObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        let initial = defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        self.subject = CurrentValueSubject(initial)

        defaultsObserver = notificationCenter.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let latest = self.defaults.string(forKey: UserDefaultsKeys.selectedMicrophoneUID) ?? ""
            if latest != self.subject.value {
                self.subject.send(latest)
            }
        }
    }

    deinit {
        if let defaultsObserver {
            notificationCenter.removeObserver(defaultsObserver)
        }
    }

    var selectedMicrophoneUID: String {
        get { subject.value }
        set {
            guard newValue != subject.value else { return }
            defaults.set(newValue, forKey: UserDefaultsKeys.selectedMicrophoneUID)
            subject.send(newValue)
        }
    }

    var selectedMicrophoneUIDPublisher: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }
}

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    static let captureDeviceConnectedNotification = Notification.Name(
        rawValue: "AVCaptureDeviceWasConnectedNotification"
    )
    static let captureDeviceDisconnectedNotification = Notification.Name(
        rawValue: "AVCaptureDeviceWasDisconnectedNotification"
    )

    @Published private(set) var availableMicrophones: [MicrophoneOption] = []
    @Published private(set) var selectedMicrophone: MicrophoneOption?

    private let settingsStore: AudioDeviceSettingsStoring
    private let defaults: UserDefaults
    private let discoverInputMicrophonesProvider: () -> [MicrophoneOption]
    private let captureAudioDevicesProvider: () -> [AVCaptureDevice]
    private let notificationCenter: NotificationCenter
    private let startMonitoringOnInit: Bool

    private var deviceObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    var selectedMicrophoneUID: String { settingsStore.selectedMicrophoneUID }
    var hasRecommendedBuiltInMicrophone: Bool {
        Self.containsRecommendedBuiltInMicrophone(availableMicrophones)
    }

    init(
        settingsStore: AudioDeviceSettingsStoring = AppSettingsAudioDeviceStore(),
        defaults: UserDefaults = .standard,
        discoverInputMicrophones: @escaping () -> [MicrophoneOption] = AudioDeviceManager.discoverInputMicrophones,
        captureAudioDevices: @escaping () -> [AVCaptureDevice] = AudioDeviceManager.captureAudioDevices,
        notificationCenter: NotificationCenter = .default,
        startMonitoringOnInit: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.defaults = defaults
        self.discoverInputMicrophonesProvider = discoverInputMicrophones
        self.captureAudioDevicesProvider = captureAudioDevices
        self.notificationCenter = notificationCenter
        self.startMonitoringOnInit = startMonitoringOnInit

        availableMicrophones = discoverInputMicrophonesProvider()
        applyInitialSelectionPolicy()
        syncSelectedMicrophone()
        settingsStore.selectedMicrophoneUIDPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncSelectedMicrophone()
            }
            .store(in: &cancellables)

        if startMonitoringOnInit {
            startMonitoringCaptureDevices()
        }
    }

    deinit {
        for observer in deviceObservers {
            notificationCenter.removeObserver(observer)
        }
    }

    var pickerMicrophones: [MicrophoneOption] {
        guard !settingsStore.selectedMicrophoneUID.isEmpty,
              selectedMicrophone == nil,
              !availableMicrophones.contains(where: { $0.id == settingsStore.selectedMicrophoneUID }) else {
            return availableMicrophones
        }

        // Preserve a missing persisted selection so users can see why the old choice is no longer active.
        let unavailable = MicrophoneOption(
            id: settingsStore.selectedMicrophoneUID,
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

        if !settingsStore.selectedMicrophoneUID.isEmpty,
           let selectedFromUID = deviceForID(settingsStore.selectedMicrophoneUID) {
            return selectedFromUID
        }

        return builtInCaptureDevice() ?? AVCaptureDevice.default(for: .audio) ?? captureAudioDevicesProvider().first
    }

    func builtInCaptureDevice() -> AVCaptureDevice? {
        if let builtInID = builtInMicrophone?.id,
           let device = deviceForID(builtInID) {
            return device
        }

        return captureAudioDevicesProvider().first {
            Self.classifyDeviceKind(for: $0) == .builtIn
        }
    }

    func refreshAvailableMicrophones() {
        let discovered = discoverInputMicrophonesProvider()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.availableMicrophones = discovered
            self.syncSelectedMicrophone()
        }
    }

    private var builtInMicrophone: MicrophoneOption? {
        availableMicrophones.first(where: { $0.kind == .builtIn && $0.isAvailable })
    }

    static func containsRecommendedBuiltInMicrophone(_ microphones: [MicrophoneOption]) -> Bool {
        microphones.contains { $0.kind == .builtIn && $0.isAvailable }
    }

    static func preferredInitialSelectionUID(
        availableMicrophones: [MicrophoneOption],
        persistedSelectedUID: String,
        hasInitializedDefault: Bool
    ) -> String? {
        let builtIn = availableMicrophones.first(where: { $0.kind == .builtIn && $0.isAvailable })

        if !hasInitializedDefault {
            if let builtIn {
                return builtIn.id
            }
            return availableMicrophones.first?.id
        }

        if persistedSelectedUID.isEmpty, let builtIn {
            return builtIn.id
        }

        return nil
    }

    private func applyInitialSelectionPolicy() {
        let hasInitialized = defaults.bool(forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)
        let initialUID = Self.preferredInitialSelectionUID(
            availableMicrophones: availableMicrophones,
            persistedSelectedUID: settingsStore.selectedMicrophoneUID,
            hasInitializedDefault: hasInitialized
        )

        if let initialUID {
            settingsStore.selectedMicrophoneUID = initialUID
        }

        if !hasInitialized {
            defaults.set(true, forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)
        }
    }

    private func syncSelectedMicrophone() {
        selectedMicrophone = availableMicrophones.first(where: { $0.id == settingsStore.selectedMicrophoneUID })
    }

    private func startMonitoringCaptureDevices() {
        let connectedObserver = notificationCenter.addObserver(
            forName: Self.captureDeviceConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableMicrophones()
        }

        let disconnectedObserver = notificationCenter.addObserver(
            forName: Self.captureDeviceDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableMicrophones()
        }

        deviceObservers = [connectedObserver, disconnectedObserver]
    }

    private func deviceForID(_ uniqueID: String) -> AVCaptureDevice? {
        captureAudioDevicesProvider().first(where: { $0.uniqueID == uniqueID })
    }

    nonisolated static func discoverInputMicrophones() -> [MicrophoneOption] {
        let devices = captureAudioDevices()
        let mapped = devices.map { device in
            MicrophoneOption(
                id: device.uniqueID,
                name: device.localizedName,
                kind: classifyDeviceKind(for: device),
                isAvailable: true
            )
        }
        return sortedMicrophones(mapped)
    }

    nonisolated static func sortedMicrophones(_ microphones: [MicrophoneOption]) -> [MicrophoneOption] {
        microphones.sorted(by: microphoneSortPredicate)
    }

    nonisolated private static func captureAudioDevices() -> [AVCaptureDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone, .external]
        } else {
            deviceTypes = [.builtInMicrophone, .externalUnknown]
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
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
        // Picker policy: built-in first (recommended), then wired/other, then Bluetooth classes.
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

    nonisolated static func classifyDeviceKind(_ input: AudioDeviceClassificationInput) -> MicrophoneKind {
        let lowered = input.name.lowercased()

        if lowered.contains("airpods") {
            return .airPods
        }

        if input.transportType == kAudioDeviceTransportTypeBluetooth ||
            input.transportType == kAudioDeviceTransportTypeBluetoothLE {
            return .bluetooth
        }

        if input.transportType == kAudioDeviceTransportTypeBuiltIn {
            return .builtIn
        }

        // Name heuristics are a fallback for devices that do not report a reliable CoreAudio transport type.
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

    nonisolated private static func classifyDeviceKind(for device: AVCaptureDevice) -> MicrophoneKind {
        classifyDeviceKind(
            AudioDeviceClassificationInput(
                name: device.localizedName,
                transportType: UInt32(bitPattern: device.transportType)
            )
        )
    }
}
