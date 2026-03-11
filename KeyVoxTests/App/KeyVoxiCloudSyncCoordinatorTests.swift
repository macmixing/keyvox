import Foundation
import XCTest
@testable import KeyVox
@testable import KeyVoxCore

@MainActor
final class KeyVoxiCloudSyncCoordinatorTests: XCTestCase {
    func testLocalDictionarySeedsEmptyCloud() async throws {
        let localDate = makeDate(year: 2026, month: 3, day: 7, hour: 12)
        let harness = try makeHarness(now: localDate)
        try harness.dictionaryStore.add(phrase: "Cueboard")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)

        let dictionaryPushed = expectation(description: "Dictionary pushed to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.dictionaryPayload {
                dictionaryPushed.fulfill()
            }
        }

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator
        await fulfillment(of: [dictionaryPushed], timeout: 1.0)

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(payload.entries.map(\.phrase), ["Cueboard"])
        XCTAssertEqual(payload.modifiedAt, localDate)
    }

    func testCloudDictionarySeedsEmptyLocal() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 8, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        try harness.cloudStore.seedDictionary(entries: [
            DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: "Dom Esposito"),
        ], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Dom Esposito"])
        XCTAssertEqual(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date, remoteDate)
    }

    func testNewerCloudDictionaryWinsOverLocal() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let harness = try makeHarness(now: remoteDate)
        try harness.dictionaryStore.add(phrase: "Old Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "New Remote Phrase")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["New Remote Phrase"])
    }

    func testOlderCloudDictionaryIsIgnored() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let harness = try makeHarness(now: localDate)
        try harness.dictionaryStore.add(phrase: "Latest Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Older Remote Phrase")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Latest Local Phrase"])
    }

    func testMalformedCloudDictionaryIsIgnored() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let harness = try makeHarness(now: localDate)
        try harness.dictionaryStore.add(phrase: "Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        harness.cloudStore.seedRaw(Data("broken".utf8), forKey: KeyVoxiCloudKeys.dictionaryPayload)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Local Phrase"])
    }

    func testLossyCloudDictionarySnapshotIsIgnored() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 11, hour: 8)
        let harness = try makeHarness(now: remoteDate)
        try harness.dictionaryStore.add(phrase: "Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [
            DictionaryEntry(phrase: " Cueboard "),
            DictionaryEntry(phrase: "cueboard"),
        ], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Local Phrase"])
        XCTAssertEqual(
            harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date,
            localDate
        )
    }

    func testLocalDictionaryChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 7, hour: 15)
        let harness = try makeHarness(now: now)
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        let dictionaryPushed = expectation(description: "Dictionary change pushed to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.dictionaryPayload {
                dictionaryPushed.fulfill()
            }
        }

        try harness.dictionaryStore.add(phrase: "MiGo Platform")
        await fulfillment(of: [dictionaryPushed], timeout: 1.0)

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(payload.entries.map(\.phrase), ["MiGo Platform"])
        XCTAssertEqual(payload.modifiedAt, now)
    }

    func testRemoteDictionaryApplyDoesNotLoopPush() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 11, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Remote Only")], modifiedAt: remoteDate)
        harness.cloudStore.resetSetCounts()

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Remote Only"])
        XCTAssertEqual(harness.cloudStore.setCount(forKey: KeyVoxiCloudKeys.dictionaryPayload), 0)
    }

    func testNewerCloudDictionaryWinsWhenOnlyPersistedFileTimestampExists() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let localEntries = [
            DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: "Old Local Phrase"),
        ]
        let harness = try makeHarness(
            now: makeDate(year: 2026, month: 3, day: 10, hour: 8),
            prepareBaseDirectory: { baseDirectoryURL in
                try self.writePersistedDictionary(entries: localEntries, modifiedAt: localDate, to: baseDirectoryURL)
            }
        )
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "New Remote Phrase")], modifiedAt: remoteDate)
        harness.cloudStore.resetSetCounts()

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["New Remote Phrase"])
        XCTAssertEqual(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date, remoteDate)
        XCTAssertEqual(harness.cloudStore.setCount(forKey: KeyVoxiCloudKeys.dictionaryPayload), 0)
    }

    func testOlderCloudDictionaryIsIgnoredWhenOnlyPersistedFileTimestampExists() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let localEntries = [
            DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: "Latest Local Phrase"),
        ]
        let harness = try makeHarness(
            now: makeDate(year: 2026, month: 3, day: 12, hour: 8),
            prepareBaseDirectory: { baseDirectoryURL in
                try self.writePersistedDictionary(entries: localEntries, modifiedAt: localDate, to: baseDirectoryURL)
            }
        )
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Older Remote Phrase")], modifiedAt: remoteDate)

        let dictionaryPushed = expectation(description: "Persisted dictionary pushed to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.dictionaryPayload {
                dictionaryPushed.fulfill()
            }
        }

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator
        wait(for: [dictionaryPushed], timeout: 1.0)

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Latest Local Phrase"])
        XCTAssertEqual(payload.entries.map(\.phrase), ["Latest Local Phrase"])
        XCTAssertEqual(payload.modifiedAt, localDate)
        XCTAssertEqual(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date, localDate)
    }

    func testPersistedDictionarySeedsEmptyCloudUsingFileTimestamp() throws {
        let localDate = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let localEntries = [
            DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: "Cueboard"),
        ]
        let harness = try makeHarness(
            now: makeDate(year: 2026, month: 3, day: 10, hour: 8),
            prepareBaseDirectory: { baseDirectoryURL in
                try self.writePersistedDictionary(entries: localEntries, modifiedAt: localDate, to: baseDirectoryURL)
            }
        )

        let dictionaryPushed = expectation(description: "Persisted dictionary seeded to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.dictionaryPayload {
                dictionaryPushed.fulfill()
            }
        }

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator
        wait(for: [dictionaryPushed], timeout: 1.0)

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(payload.entries.map(\.phrase), ["Cueboard"])
        XCTAssertEqual(payload.modifiedAt, localDate)
        XCTAssertEqual(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date, localDate)
    }

    func testNewerCloudAutoParagraphsAppliesLocally() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        harness.cloudStore.seedValue(false, forKey: KeyVoxiCloudKeys.autoParagraphsEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertFalse(harness.appSettings.autoParagraphsEnabled)
    }

    func testNewerCloudTriggerBindingAppliesLocally() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        harness.cloudStore.seedValue(AppSettingsStore.TriggerBinding.leftCommand.rawValue, forKey: KeyVoxiCloudKeys.triggerBinding)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.appSettings.triggerBinding, .leftCommand)
    }

    func testLocalListFormattingChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let harness = try makeHarness(now: now)
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        let listFormattingPushed = expectation(description: "List formatting pushed to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.listFormattingModifiedAt {
                listFormattingPushed.fulfill()
            }
        }

        harness.appSettings.listFormattingEnabled = false
        await fulfillment(of: [listFormattingPushed], timeout: 1.0)

        XCTAssertEqual(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingEnabled) as? Bool, false)
        XCTAssertEqual(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingModifiedAt) as? Date, now)
    }

    func testLocalTriggerBindingChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 13)
        let harness = try makeHarness(now: now)
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        let triggerBindingPushed = expectation(description: "Trigger binding pushed to cloud")
        harness.cloudStore.onSet = { key in
            if key == KeyVoxiCloudKeys.triggerBindingModifiedAt {
                triggerBindingPushed.fulfill()
            }
        }

        harness.appSettings.triggerBinding = .leftControl
        await fulfillment(of: [triggerBindingPushed], timeout: 1.0)

        XCTAssertEqual(
            harness.cloudStore.object(forKey: KeyVoxiCloudKeys.triggerBinding) as? String,
            AppSettingsStore.TriggerBinding.leftControl.rawValue
        )
        XCTAssertEqual(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt) as? Date, now)
    }

    private func makeCoordinator(harness: Harness) -> KeyVoxiCloudSyncCoordinator {
        KeyVoxiCloudSyncCoordinator(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            appSettings: harness.appSettings,
            dictionaryStore: harness.dictionaryStore,
            defaults: harness.defaults,
            now: harness.now
        )
    }

    private func makeHarness(
        now: Date,
        prepareBaseDirectory: ((URL) throws -> Void)? = nil
    ) throws -> Harness {
        let suiteName = "KeyVoxiCloudSyncCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyVoxiCloudSyncCoordinatorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try prepareBaseDirectory?(base)

        let appSettings = AppSettingsStore(defaults: defaults)
        let dictionaryStore = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

        let harness = Harness(
            defaults: defaults,
            appSettings: appSettings,
            dictionaryStore: dictionaryStore,
            cloudStore: InMemoryUbiquitousKeyValueStore(),
            notificationCenter: NotificationCenter(),
            now: { now },
            baseDirectoryURL: base,
            defaultsSuiteName: suiteName
        )

        addTeardownBlock { [harness] in
            try? harness.removeTemporaryDirectory()
            harness.defaults.removePersistentDomain(forName: harness.defaultsSuiteName)
        }

        return harness
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }

    private func writePersistedDictionary(
        entries: [DictionaryEntry],
        modifiedAt: Date,
        to baseDirectoryURL: URL
    ) throws {
        let dictionaryDirectoryURL = baseDirectoryURL.appendingPathComponent("Dictionary", isDirectory: true)
        let dictionaryFileURL = dictionaryDirectoryURL.appendingPathComponent("dictionary.json")

        try FileManager.default.createDirectory(at: dictionaryDirectoryURL, withIntermediateDirectories: true)
        let payload = PersistedDictionaryPayload(version: 1, entries: entries)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: dictionaryFileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: dictionaryFileURL.path
        )
    }
}

private struct PersistedDictionaryPayload: Codable {
    let version: Int
    let entries: [DictionaryEntry]
}

private struct Harness {
    let defaults: UserDefaults
    let appSettings: AppSettingsStore
    let dictionaryStore: DictionaryStore
    let cloudStore: InMemoryUbiquitousKeyValueStore
    let notificationCenter: NotificationCenter
    let now: () -> Date
    let baseDirectoryURL: URL
    let defaultsSuiteName: String

    func removeTemporaryDirectory() throws {
        if FileManager.default.fileExists(atPath: baseDirectoryURL.path) {
            try FileManager.default.removeItem(at: baseDirectoryURL)
        }
    }
}

private final class InMemoryUbiquitousKeyValueStore: KeyVoxiCloudKeyValueStoring {
    var notificationObject: AnyObject? { nil }

    private var storage: [String: Any] = [:]
    private var setCounts: [String: Int] = [:]
    var onSet: ((String) -> Void)?

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
        setCounts[key, default: 0] += 1
        onSet?(key)
    }

    func synchronize() -> Bool {
        true
    }

    @MainActor
    func seedDictionary(entries: [DictionaryEntry], modifiedAt: Date) throws {
        let payload = KeyVoxDictionaryCloudPayload(modifiedAt: modifiedAt, entries: entries)
        storage[KeyVoxiCloudKeys.dictionaryPayload] = try JSONEncoder().encode(payload)
        storage[KeyVoxiCloudKeys.dictionaryModifiedAt] = modifiedAt
    }

    func seedValue(_ value: Any, forKey key: String) {
        storage[key] = value
    }

    func seedRaw(_ value: Any, forKey key: String) {
        storage[key] = value
    }

    @MainActor
    func dictionaryPayload() throws -> KeyVoxDictionaryCloudPayload? {
        guard let data = storage[KeyVoxiCloudKeys.dictionaryPayload] as? Data else { return nil }
        return try JSONDecoder().decode(KeyVoxDictionaryCloudPayload.self, from: data)
    }

    func setCount(forKey key: String) -> Int {
        setCounts[key, default: 0]
    }

    func resetSetCounts() {
        setCounts = [:]
    }
}
