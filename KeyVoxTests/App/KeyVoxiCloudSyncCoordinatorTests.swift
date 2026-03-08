import Foundation
import XCTest
@testable import KeyVox
@testable import KeyVoxCore

@MainActor
final class KeyVoxiCloudSyncCoordinatorTests: XCTestCase {
    func testLocalDictionarySeedsEmptyCloud() async throws {
        let harness = try makeHarness(now: makeDate(year: 2026, month: 3, day: 7, hour: 12))
        try harness.dictionaryStore.add(phrase: "Cueboard")

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator
        await Task.yield()

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(payload.entries.map(\.phrase), ["Cueboard"])
        XCTAssertEqual(payload.modifiedAt, makeDate(year: 2026, month: 3, day: 7, hour: 12))
    }

    func testCloudDictionarySeedsEmptyLocal() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 8, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        harness.cloudStore.seedDictionary(entries: [
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
        harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "New Remote Phrase")], modifiedAt: remoteDate)

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
        harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Older Remote Phrase")], modifiedAt: remoteDate)

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

    func testLocalDictionaryChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 7, hour: 15)
        let harness = try makeHarness(now: now)
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        try harness.dictionaryStore.add(phrase: "MiGo Platform")
        await Task.yield()

        let payload = try XCTUnwrap(harness.cloudStore.dictionaryPayload())
        XCTAssertEqual(payload.entries.map(\.phrase), ["MiGo Platform"])
        XCTAssertEqual(payload.modifiedAt, now)
    }

    func testRemoteDictionaryApplyDoesNotLoopPush() throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 11, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Remote Only")], modifiedAt: remoteDate)
        harness.cloudStore.resetSetCounts()

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertEqual(harness.dictionaryStore.entries.map(\.phrase), ["Remote Only"])
        XCTAssertEqual(harness.cloudStore.setCount(forKey: KeyVoxiCloudKeys.dictionaryPayload), 0)
    }

    func testNewerCloudAutoParagraphsAppliesLocally() {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 9)
        let harness = try! makeHarness(now: remoteDate)
        harness.cloudStore.seedValue(false, forKey: KeyVoxiCloudKeys.autoParagraphsEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        XCTAssertFalse(harness.appSettings.autoParagraphsEnabled)
    }

    func testLocalListFormattingChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let harness = try makeHarness(now: now)
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.appSettings.listFormattingEnabled = false
        await Task.yield()

        XCTAssertEqual(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingEnabled) as? Bool, false)
        XCTAssertEqual(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingModifiedAt) as? Date, now)
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

    private func makeHarness(now: Date) throws -> Harness {
        let suiteName = "KeyVoxiCloudSyncCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyVoxiCloudSyncCoordinatorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let appSettings = AppSettingsStore(defaults: defaults, now: { now })
        let dictionaryStore = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

        return Harness(
            defaults: defaults,
            appSettings: appSettings,
            dictionaryStore: dictionaryStore,
            cloudStore: InMemoryUbiquitousKeyValueStore(),
            notificationCenter: NotificationCenter(),
            now: { now }
        )
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
}

private struct Harness {
    let defaults: UserDefaults
    let appSettings: AppSettingsStore
    let dictionaryStore: DictionaryStore
    let cloudStore: InMemoryUbiquitousKeyValueStore
    let notificationCenter: NotificationCenter
    let now: () -> Date
}

private final class InMemoryUbiquitousKeyValueStore: KeyVoxiCloudKeyValueStoring {
    var notificationObject: AnyObject? { nil }

    private var storage: [String: Any] = [:]
    private var setCounts: [String: Int] = [:]

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
    }

    func synchronize() -> Bool {
        true
    }

    @MainActor
    func seedDictionary(entries: [DictionaryEntry], modifiedAt: Date) {
        let payload = KeyVoxDictionaryCloudPayload(modifiedAt: modifiedAt, entries: entries)
        storage[KeyVoxiCloudKeys.dictionaryPayload] = try! JSONEncoder().encode(payload)
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
