import Foundation
import Testing
@testable import KeyVox_iOS
@testable import KeyVoxCore

@MainActor
struct CloudSyncCoordinatorTests {
    @Test func localDictionarySeedsEmptyCloud() async throws {
        let harness = try makeHarness(now: makeDate(year: 2026, month: 3, day: 7, hour: 12))
        defer { harness.cleanup() }
        try harness.dictionaryStore.add(phrase: "Cueboard")

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator
        try await waitUntil { harness.cloudStore.dictionaryPayload() != nil }

        let payload = try #require(harness.cloudStore.dictionaryPayload())
        #expect(payload.entries.map(\.phrase) == ["Cueboard"])
        #expect(payload.modifiedAt == makeDate(year: 2026, month: 3, day: 7, hour: 12))
    }

    @Test func cloudDictionarySeedsEmptyLocal() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 8, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Dom Esposito")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["Dom Esposito"])
        #expect(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date == remoteDate)
    }

    @Test func newerCloudDictionaryWins() async throws {
        let localDate = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        try harness.dictionaryStore.add(phrase: "Old Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "New Remote Phrase")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["New Remote Phrase"])
    }

    @Test func olderCloudDictionaryIsIgnored() async throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 9, hour: 8)
        let harness = try makeHarness(now: localDate)
        defer { harness.cleanup() }
        try harness.dictionaryStore.add(phrase: "Latest Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Older Remote Phrase")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["Latest Local Phrase"])
    }

    @Test func malformedCloudDictionaryIsIgnored() async throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let harness = try makeHarness(now: localDate)
        defer { harness.cleanup() }
        try harness.dictionaryStore.add(phrase: "Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        harness.cloudStore.seedRaw(Data("broken".utf8), forKey: KeyVoxiCloudKeys.dictionaryPayload)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["Local Phrase"])
    }

    @Test func lossyCloudDictionarySnapshotIsRejected() async throws {
        let localDate = makeDate(year: 2026, month: 3, day: 10, hour: 8)
        let remoteDate = makeDate(year: 2026, month: 3, day: 11, hour: 8)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        try harness.dictionaryStore.add(phrase: "Local Phrase")
        harness.defaults.set(localDate, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: " Cueboard "), DictionaryEntry(phrase: "cueboard")], modifiedAt: remoteDate)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["Local Phrase"])
        #expect(harness.defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date == localDate)
    }

    @Test func localDictionaryChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 7, hour: 15)
        let harness = try makeHarness(now: now)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        try harness.dictionaryStore.add(phrase: "MiGo Platform")
        try await waitUntil { harness.cloudStore.dictionaryPayload() != nil }

        let payload = try #require(harness.cloudStore.dictionaryPayload())
        #expect(payload.entries.map(\.phrase) == ["MiGo Platform"])
        #expect(payload.modifiedAt == now)
    }

    @Test func remoteDictionaryApplyDoesNotLoopPush() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 11, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        try harness.cloudStore.seedDictionary(entries: [DictionaryEntry(phrase: "Remote Only")], modifiedAt: remoteDate)
        harness.cloudStore.resetSetCounts()

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.dictionaryStore.entries.map(\.phrase) == ["Remote Only"])
        #expect(harness.cloudStore.setCount(forKey: KeyVoxiCloudKeys.dictionaryPayload) == 0)
    }

    @Test func newerCloudTriggerBindingAppliesLocally() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        harness.cloudStore.seedValue(AppSettingsStore.TriggerBinding.leftCommand.rawValue, forKey: KeyVoxiCloudKeys.triggerBinding)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.settingsStore.triggerBinding == .leftCommand)
    }

    @Test func malformedRemoteTriggerBindingIsIgnored() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 10)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.cloudStore.seedValue("not-a-binding", forKey: KeyVoxiCloudKeys.triggerBinding)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt)
        coordinator.processExternalChanges(for: [KeyVoxiCloudKeys.triggerBinding, KeyVoxiCloudKeys.triggerBindingModifiedAt])

        #expect(harness.settingsStore.triggerBinding == .rightOption)
    }

    @Test func localTriggerBindingChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 13)
        let harness = try makeHarness(now: now)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.settingsStore.triggerBinding = .leftControl
        try await waitUntil { harness.cloudStore.object(forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt) as? Date == now }

        #expect(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.triggerBinding) as? String == AppSettingsStore.TriggerBinding.leftControl.rawValue)
    }

    @Test func newerCloudAutoParagraphsAppliesLocally() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        harness.cloudStore.seedValue(false, forKey: KeyVoxiCloudKeys.autoParagraphsEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.settingsStore.autoParagraphsEnabled == false)
    }

    @Test func malformedRemoteAutoParagraphsIsIgnored() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 9)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.cloudStore.seedValue("nope", forKey: KeyVoxiCloudKeys.autoParagraphsEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt)
        coordinator.processExternalChanges(for: [KeyVoxiCloudKeys.autoParagraphsEnabled, KeyVoxiCloudKeys.autoParagraphsModifiedAt])

        #expect(harness.settingsStore.autoParagraphsEnabled == true)
    }

    @Test func localAutoParagraphsChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let harness = try makeHarness(now: now)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.settingsStore.autoParagraphsEnabled = false
        try await waitUntil { harness.cloudStore.object(forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt) as? Date == now }

        #expect(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.autoParagraphsEnabled) as? Bool == false)
    }

    @Test func newerCloudListFormattingAppliesLocally() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 11)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        harness.cloudStore.seedValue(false, forKey: KeyVoxiCloudKeys.listFormattingEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.listFormattingModifiedAt)

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.settingsStore.listFormattingEnabled == false)
    }

    @Test func malformedRemoteListFormattingIsIgnored() async throws {
        let remoteDate = makeDate(year: 2026, month: 3, day: 12, hour: 11)
        let harness = try makeHarness(now: remoteDate)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.cloudStore.seedValue("bad", forKey: KeyVoxiCloudKeys.listFormattingEnabled)
        harness.cloudStore.seedValue(remoteDate, forKey: KeyVoxiCloudKeys.listFormattingModifiedAt)
        coordinator.processExternalChanges(for: [KeyVoxiCloudKeys.listFormattingEnabled, KeyVoxiCloudKeys.listFormattingModifiedAt])

        #expect(harness.settingsStore.listFormattingEnabled == true)
    }

    @Test func localListFormattingChangePushesCloud() async throws {
        let now = makeDate(year: 2026, month: 3, day: 12, hour: 14)
        let harness = try makeHarness(now: now)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        harness.settingsStore.listFormattingEnabled = false
        try await waitUntil { harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingModifiedAt) as? Date == now }

        #expect(harness.cloudStore.object(forKey: KeyVoxiCloudKeys.listFormattingEnabled) as? Bool == false)
    }

    @Test func emptyEverywhereBootstrapDoesNothing() async throws {
        let harness = try makeHarness(now: makeDate(year: 2026, month: 3, day: 12, hour: 15))
        defer { harness.cleanup() }

        let coordinator = makeCoordinator(harness: harness)
        _ = coordinator

        #expect(harness.cloudStore.storage.isEmpty)
        #expect(harness.dictionaryStore.entries.isEmpty)
        #expect(harness.settingsStore.triggerBinding == .rightOption)
        #expect(harness.settingsStore.autoParagraphsEnabled == true)
        #expect(harness.settingsStore.listFormattingEnabled == true)
    }

    private func makeCoordinator(harness: Harness) -> CloudSyncCoordinator {
        CloudSyncCoordinator(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            settingsStore: harness.settingsStore,
            dictionaryStore: harness.dictionaryStore,
            defaults: harness.defaults,
            now: harness.now
        )
    }

    private func makeHarness(now: Date) throws -> Harness {
        let suiteName = "CloudSyncCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncCoordinatorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let settingsStore = AppSettingsStore(defaults: defaults)
        let dictionaryStore = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

        return Harness(
            defaults: defaults,
            settingsStore: settingsStore,
            dictionaryStore: dictionaryStore,
            cloudStore: InMemoryUbiquitousKeyValueStore(),
            notificationCenter: NotificationCenter(),
            now: { now },
            baseDirectoryURL: base,
            defaultsSuiteName: suiteName
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

    private func waitUntil(timeout: TimeInterval = 1.0, condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                Issue.record("Timed out waiting for condition.")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private struct Harness {
    let defaults: UserDefaults
    let settingsStore: AppSettingsStore
    let dictionaryStore: DictionaryStore
    let cloudStore: InMemoryUbiquitousKeyValueStore
    let notificationCenter: NotificationCenter
    let now: () -> Date
    let baseDirectoryURL: URL
    let defaultsSuiteName: String

    func cleanup() {
        if FileManager.default.fileExists(atPath: baseDirectoryURL.path) {
            try? FileManager.default.removeItem(at: baseDirectoryURL)
        }
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}

private final class InMemoryUbiquitousKeyValueStore: CloudKeyValueStoring {
    var notificationObject: AnyObject? { nil }

    var storage: [String: Any] = [:]
    private var setCounts: [String: Int] = [:]

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
        setCounts[key, default: 0] += 1
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

    func dictionaryPayload() -> KeyVoxDictionaryCloudPayload? {
        guard let data = storage[KeyVoxiCloudKeys.dictionaryPayload] as? Data else { return nil }
        return try? JSONDecoder().decode(KeyVoxDictionaryCloudPayload.self, from: data)
    }

    func setCount(forKey key: String) -> Int {
        setCounts[key, default: 0]
    }

    func resetSetCounts() {
        setCounts.removeAll()
    }
}
