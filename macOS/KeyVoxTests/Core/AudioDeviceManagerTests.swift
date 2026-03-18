import Combine
import XCTest
@testable import KeyVox
import CoreAudio

@MainActor
final class AudioDeviceManagerTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testClassificationMatrixUsesTransportTypeOnly() {
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeBuiltIn)
            ),
            .builtIn
        )
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeBluetooth)
            ),
            .bluetooth
        )
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeUSB)
            ),
            .wiredOrOther
        )
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeUSB)
            ),
            .wiredOrOther
        )
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeUSB)
            ),
            .wiredOrOther
        )
        XCTAssertEqual(
            AudioDeviceManager.classifyDeviceKind(
                AudioDeviceClassificationInput(transportType: kAudioDeviceTransportTypeUSB)
            ),
            .wiredOrOther
        )
    }

    func testCompatibleHeadphoneOverrideRelabelsSingleBluetoothMicrophoneAsAirPods() {
        let microphones: [MicrophoneOption] = [
            .init(id: "usb", name: "USB Mic", kind: .wiredOrOther, isAvailable: true),
            .init(id: "bt", name: "Bluetooth Headset", kind: .bluetooth, isAvailable: true)
        ]

        let overridden = AudioDeviceManager.applyCompatibleHeadphoneOverrides(
            to: microphones,
            compatibleHeadphonesConnected: true,
            selectedMicrophoneUID: ""
        )

        XCTAssertEqual(overridden.first(where: { $0.id == "bt" })?.kind, .airPods)
        XCTAssertEqual(overridden.first(where: { $0.id == "usb" })?.kind, .wiredOrOther)
    }

    func testCompatibleHeadphoneOverridePrefersSelectedBluetoothMicrophoneWhenMultipleExist() {
        let microphones: [MicrophoneOption] = [
            .init(id: "bt-1", name: "Bluetooth Mic A", kind: .bluetooth, isAvailable: true),
            .init(id: "bt-2", name: "Bluetooth Mic B", kind: .bluetooth, isAvailable: true),
            .init(id: "builtin", name: "Built-in Mic", kind: .builtIn, isAvailable: true)
        ]

        let overridden = AudioDeviceManager.applyCompatibleHeadphoneOverrides(
            to: microphones,
            compatibleHeadphonesConnected: true,
            selectedMicrophoneUID: "bt-2"
        )

        XCTAssertEqual(overridden.first(where: { $0.id == "bt-2" })?.kind, .airPods)
        XCTAssertEqual(overridden.first(where: { $0.id == "bt-1" })?.kind, .bluetooth)
        XCTAssertEqual(overridden.first(where: { $0.id == "builtin" })?.kind, .builtIn)
    }

    func testCompatibleHeadphoneOverrideLeavesDevicesUnchangedWhenDisconnected() {
        let microphones: [MicrophoneOption] = [
            .init(id: "bt", name: "Bluetooth Headset", kind: .bluetooth, isAvailable: true),
            .init(id: "builtin", name: "Built-in Mic", kind: .builtIn, isAvailable: true)
        ]

        let overridden = AudioDeviceManager.applyCompatibleHeadphoneOverrides(
            to: microphones,
            compatibleHeadphonesConnected: false,
            selectedMicrophoneUID: "bt"
        )

        XCTAssertEqual(overridden, microphones)
    }

    func testSortedMicrophonesPrioritizeBuiltInThenWiredThenAirPodsThenBluetooth() {
        let microphones: [MicrophoneOption] = [
            .init(id: "4", name: "Bluetooth Headset", kind: .bluetooth, isAvailable: true),
            .init(id: "3", name: "AirPods", kind: .airPods, isAvailable: true),
            .init(id: "2", name: "USB Mic", kind: .wiredOrOther, isAvailable: true),
            .init(id: "1", name: "Built-in Mic", kind: .builtIn, isAvailable: true)
        ]

        let sorted = AudioDeviceManager.sortedMicrophones(microphones)

        XCTAssertEqual(sorted.map(\.id), ["1", "2", "3", "4"])
    }

    func testPreferredInitialSelectionUIDFirstLaunchUsesBuiltInThenSetsInitializedFlag() {
        let defaults = makeIsolatedDefaults()
        let settings = MockAudioDeviceSettingsStore(selectedMicrophoneUID: "")
        let available: [MicrophoneOption] = [
            .init(id: "usb", name: "USB Mic", kind: .wiredOrOther, isAvailable: true),
            .init(id: "builtin", name: "Built-in", kind: .builtIn, isAvailable: true)
        ]

        let manager = AudioDeviceManager(
            settingsStore: settings,
            defaults: defaults,
            discoverInputMicrophones: { available },
            captureAudioDevices: { [] },
            notificationCenter: .default,
            startMonitoringOnInit: false
        )

        _ = manager
        XCTAssertEqual(settings.selectedMicrophoneUID, "builtin")
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault))
    }

    func testPersistedSelectionHydratesWhenAvailable() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)

        let settings = MockAudioDeviceSettingsStore(selectedMicrophoneUID: "usb")
        let available: [MicrophoneOption] = [
            .init(id: "builtin", name: "Built-in", kind: .builtIn, isAvailable: true),
            .init(id: "usb", name: "USB Mic", kind: .wiredOrOther, isAvailable: true)
        ]

        let manager = AudioDeviceManager(
            settingsStore: settings,
            defaults: defaults,
            discoverInputMicrophones: { available },
            captureAudioDevices: { [] },
            notificationCenter: .default,
            startMonitoringOnInit: false
        )

        XCTAssertEqual(manager.selectedMicrophone?.id, "usb")
        XCTAssertEqual(settings.selectedMicrophoneUID, "usb")
    }

    func testMissingPersistedSelectionShowsUnavailablePickerEntry() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.hasInitializedMicrophoneDefault)

        let settings = MockAudioDeviceSettingsStore(selectedMicrophoneUID: "missing-mic")
        let available: [MicrophoneOption] = [
            .init(id: "builtin", name: "Built-in", kind: .builtIn, isAvailable: true)
        ]

        let manager = AudioDeviceManager(
            settingsStore: settings,
            defaults: defaults,
            discoverInputMicrophones: { available },
            captureAudioDevices: { [] },
            notificationCenter: .default,
            startMonitoringOnInit: false
        )

        XCTAssertNil(manager.selectedMicrophone)
        let picker = manager.pickerMicrophones
        XCTAssertEqual(picker.count, 2)
        XCTAssertEqual(picker.last?.id, "missing-mic")
        XCTAssertEqual(picker.last?.isAvailable, false)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "AudioDeviceManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

private final class MockAudioDeviceSettingsStore: AudioDeviceSettingsStoring {
    private let subject: CurrentValueSubject<String, Never>

    init(selectedMicrophoneUID: String) {
        self.subject = CurrentValueSubject(selectedMicrophoneUID)
    }

    var selectedMicrophoneUID: String {
        get { subject.value }
        set { subject.send(newValue) }
    }

    var selectedMicrophoneUIDPublisher: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }
}
