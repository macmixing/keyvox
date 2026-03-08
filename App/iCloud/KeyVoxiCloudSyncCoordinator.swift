import Foundation
import Combine
import KeyVoxCore

protocol KeyVoxiCloudKeyValueStoring: AnyObject {
    var notificationObject: AnyObject? { get }
    func object(forKey key: String) -> Any?
    func data(forKey key: String) -> Data?
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyVoxiCloudKeyValueStoring {
    var notificationObject: AnyObject? { self }
}

@MainActor
final class KeyVoxiCloudSyncCoordinator {
    private let ubiquitousStore: any KeyVoxiCloudKeyValueStoring
    private let notificationCenter: NotificationCenter
    private let appSettings: AppSettingsStore
    private let dictionaryStore: DictionaryStore
    private let defaults: UserDefaults
    private let now: () -> Date

    private var cancellables = Set<AnyCancellable>()
    private var externalChangeObserver: NSObjectProtocol?
    private var isApplyingRemoteDictionary = false
    private var isApplyingRemoteAutoParagraphs = false
    private var isApplyingRemoteListFormatting = false

    init(
        ubiquitousStore: any KeyVoxiCloudKeyValueStoring = NSUbiquitousKeyValueStore.default,
        notificationCenter: NotificationCenter = .default,
        appSettings: AppSettingsStore,
        dictionaryStore: DictionaryStore,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.ubiquitousStore = ubiquitousStore
        self.notificationCenter = notificationCenter
        self.appSettings = appSettings
        self.dictionaryStore = dictionaryStore
        self.defaults = defaults
        self.now = now

        setupObservers()
        registerForExternalChanges()
        _ = ubiquitousStore.synchronize()
        bootstrap()
    }

    deinit {
        if let externalChangeObserver {
            notificationCenter.removeObserver(externalChangeObserver)
        }
    }

    func processExternalChanges(for changedKeys: [String]) {
        if changedKeys.contains(KeyVoxiCloudKeys.dictionaryPayload)
            || changedKeys.contains(KeyVoxiCloudKeys.dictionaryModifiedAt) {
            applyRemoteDictionaryIfNewer()
        }

        if changedKeys.contains(KeyVoxiCloudKeys.autoParagraphsEnabled)
            || changedKeys.contains(KeyVoxiCloudKeys.autoParagraphsModifiedAt) {
            applyRemoteAutoParagraphsIfNewer()
        }

        if changedKeys.contains(KeyVoxiCloudKeys.listFormattingEnabled)
            || changedKeys.contains(KeyVoxiCloudKeys.listFormattingModifiedAt) {
            applyRemoteListFormattingIfNewer()
        }
    }

    private func setupObservers() {
        dictionaryStore.$entries
            .dropFirst()
            .sink { [weak self] entries in
                guard let self, !self.isApplyingRemoteDictionary else { return }
                let modifiedAt = self.now()
                self.setLocalDictionaryModifiedAt(modifiedAt)
                self.pushDictionary(entries: entries, modifiedAt: modifiedAt)
            }
            .store(in: &cancellables)

        appSettings.$autoParagraphsEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self, !self.isApplyingRemoteAutoParagraphs else { return }
                let modifiedAt = self.now()
                self.setLocalAutoParagraphsModifiedAt(modifiedAt)
                self.pushSetting(value, valueKey: KeyVoxiCloudKeys.autoParagraphsEnabled, modifiedAtKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt, modifiedAt: modifiedAt)
            }
            .store(in: &cancellables)

        appSettings.$listFormattingEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self, !self.isApplyingRemoteListFormatting else { return }
                let modifiedAt = self.now()
                self.setLocalListFormattingModifiedAt(modifiedAt)
                self.pushSetting(value, valueKey: KeyVoxiCloudKeys.listFormattingEnabled, modifiedAtKey: KeyVoxiCloudKeys.listFormattingModifiedAt, modifiedAt: modifiedAt)
            }
            .store(in: &cancellables)
    }

    private func registerForExternalChanges() {
        guard let notificationObject = ubiquitousStore.notificationObject else { return }
        externalChangeObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: notificationObject,
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processExternalChanges(for: changedKeys)
            }
        }
    }

    private func bootstrap() {
        bootstrapDictionary()
        bootstrapAutoParagraphs()
        bootstrapListFormatting()
    }

    private func bootstrapDictionary() {
        let localEntries = dictionaryStore.entries
        let localModifiedAt = inferredLocalDictionaryModifiedAt()
        let remotePayload = loadRemoteDictionaryPayload()

        switch (localEntries.isEmpty, remotePayload) {
        case (true, nil):
            return
        case (false, nil):
            let modifiedAt = localModifiedAt ?? now()
            setLocalDictionaryModifiedAt(modifiedAt)
            pushDictionary(entries: localEntries, modifiedAt: modifiedAt)
        case (true, .some(let payload)):
            applyRemoteDictionary(payload)
        case (false, .some(let payload)):
            let modifiedAt = localModifiedAt ?? now()
            setLocalDictionaryModifiedAt(modifiedAt)
            if payload.modifiedAt > modifiedAt {
                applyRemoteDictionary(payload)
            } else if payload.modifiedAt < modifiedAt {
                pushDictionary(entries: localEntries, modifiedAt: modifiedAt)
            }
        }
    }

    private func bootstrapAutoParagraphs() {
        bootstrapSetting(
            localValue: appSettings.autoParagraphsEnabled,
            localModifiedAt: inferredLocalAutoParagraphsModifiedAt(defaultValue: true),
            valueKey: KeyVoxiCloudKeys.autoParagraphsEnabled,
            modifiedAtKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt,
            applyRemote: { [weak self] value, modifiedAt in
                self?.applyRemoteAutoParagraphs(value: value, modifiedAt: modifiedAt)
            },
            defaultValue: true
        )
    }

    private func bootstrapListFormatting() {
        bootstrapSetting(
            localValue: appSettings.listFormattingEnabled,
            localModifiedAt: inferredLocalListFormattingModifiedAt(defaultValue: true),
            valueKey: KeyVoxiCloudKeys.listFormattingEnabled,
            modifiedAtKey: KeyVoxiCloudKeys.listFormattingModifiedAt,
            applyRemote: { [weak self] value, modifiedAt in
                self?.applyRemoteListFormatting(value: value, modifiedAt: modifiedAt)
            },
            defaultValue: true
        )
    }

    private func bootstrapSetting(
        localValue: Bool,
        localModifiedAt: Date?,
        valueKey: String,
        modifiedAtKey: String,
        applyRemote: (Bool, Date) -> Void,
        defaultValue: Bool
    ) {
        guard let remoteModifiedAt = ubiquitousStore.object(forKey: modifiedAtKey) as? Date else {
            if let localModifiedAt {
                pushSetting(localValue, valueKey: valueKey, modifiedAtKey: modifiedAtKey, modifiedAt: localModifiedAt)
            } else if localValue != defaultValue {
                let modifiedAt = now()
                updateLocalSettingTimestamp(for: modifiedAtKey, value: modifiedAt)
                pushSetting(localValue, valueKey: valueKey, modifiedAtKey: modifiedAtKey, modifiedAt: modifiedAt)
            }
            return
        }

        let remoteValue = ubiquitousStore.bool(forKey: valueKey)
        guard let resolvedLocalModifiedAt = localModifiedAt else {
            if localValue == defaultValue {
                applyRemote(remoteValue, remoteModifiedAt)
            } else {
                let modifiedAt = now()
                updateLocalSettingTimestamp(for: modifiedAtKey, value: modifiedAt)
                pushSetting(localValue, valueKey: valueKey, modifiedAtKey: modifiedAtKey, modifiedAt: modifiedAt)
            }
            return
        }

        updateLocalSettingTimestamp(for: modifiedAtKey, value: resolvedLocalModifiedAt)

        if remoteModifiedAt > resolvedLocalModifiedAt {
            applyRemote(remoteValue, remoteModifiedAt)
        } else if remoteModifiedAt < resolvedLocalModifiedAt {
            pushSetting(localValue, valueKey: valueKey, modifiedAtKey: modifiedAtKey, modifiedAt: resolvedLocalModifiedAt)
        }
    }

    private func applyRemoteDictionaryIfNewer() {
        guard let payload = loadRemoteDictionaryPayload() else { return }
        let localModifiedAt = localDictionaryModifiedAt() ?? .distantPast
        guard payload.modifiedAt > localModifiedAt else { return }
        applyRemoteDictionary(payload)
    }

    private func applyRemoteDictionary(_ payload: KeyVoxDictionaryCloudPayload) {
        isApplyingRemoteDictionary = true
        defer { isApplyingRemoteDictionary = false }

        do {
            if dictionaryStore.entries != payload.entries {
                try dictionaryStore.replaceAll(entries: payload.entries)
            }
            setLocalDictionaryModifiedAt(payload.modifiedAt)
        } catch {
            #if DEBUG
            print("[iCloudSync] Failed to apply remote dictionary payload: \(error)")
            #endif
        }
    }

    private func applyRemoteAutoParagraphsIfNewer() {
        guard
            let remoteModifiedAt = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt) as? Date
        else {
            return
        }

        let localModifiedAt = autoParagraphsModifiedAt() ?? .distantPast
        guard remoteModifiedAt > localModifiedAt else { return }
        applyRemoteAutoParagraphs(
            value: ubiquitousStore.bool(forKey: KeyVoxiCloudKeys.autoParagraphsEnabled),
            modifiedAt: remoteModifiedAt
        )
    }

    private func applyRemoteAutoParagraphs(value: Bool, modifiedAt: Date) {
        isApplyingRemoteAutoParagraphs = true
        defer { isApplyingRemoteAutoParagraphs = false }

        appSettings.applyCloudAutoParagraphsEnabled(value)
        setLocalAutoParagraphsModifiedAt(modifiedAt)
    }

    private func applyRemoteListFormattingIfNewer() {
        guard
            let remoteModifiedAt = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.listFormattingModifiedAt) as? Date
        else {
            return
        }

        let localModifiedAt = listFormattingModifiedAt() ?? .distantPast
        guard remoteModifiedAt > localModifiedAt else { return }
        applyRemoteListFormatting(
            value: ubiquitousStore.bool(forKey: KeyVoxiCloudKeys.listFormattingEnabled),
            modifiedAt: remoteModifiedAt
        )
    }

    private func applyRemoteListFormatting(value: Bool, modifiedAt: Date) {
        isApplyingRemoteListFormatting = true
        defer { isApplyingRemoteListFormatting = false }

        appSettings.applyCloudListFormattingEnabled(value)
        setLocalListFormattingModifiedAt(modifiedAt)
    }

    private func pushDictionary(entries: [DictionaryEntry], modifiedAt: Date) {
        let payload = KeyVoxDictionaryCloudPayload(modifiedAt: modifiedAt, entries: entries)

        do {
            let data = try JSONEncoder().encode(payload)
            ubiquitousStore.set(data, forKey: KeyVoxiCloudKeys.dictionaryPayload)
            ubiquitousStore.set(modifiedAt, forKey: KeyVoxiCloudKeys.dictionaryModifiedAt)
            _ = ubiquitousStore.synchronize()
        } catch {
            #if DEBUG
            print("[iCloudSync] Failed to encode dictionary payload: \(error)")
            #endif
        }
    }

    private func pushSetting(_ value: Bool, valueKey: String, modifiedAtKey: String, modifiedAt: Date) {
        ubiquitousStore.set(value, forKey: valueKey)
        ubiquitousStore.set(modifiedAt, forKey: modifiedAtKey)
        _ = ubiquitousStore.synchronize()
    }

    private func loadRemoteDictionaryPayload() -> KeyVoxDictionaryCloudPayload? {
        guard let data = ubiquitousStore.data(forKey: KeyVoxiCloudKeys.dictionaryPayload) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(KeyVoxDictionaryCloudPayload.self, from: data)
        } catch {
            #if DEBUG
            print("[iCloudSync] Failed to decode remote dictionary payload: \(error)")
            #endif
            return nil
        }
    }

    private func localDictionaryModifiedAt() -> Date? {
        defaults.object(forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date
    }

    private func setLocalDictionaryModifiedAt(_ value: Date) {
        defaults.set(value, forKey: UserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
    }

    private func autoParagraphsModifiedAt() -> Date? {
        defaults.object(forKey: UserDefaultsKeys.iCloud.autoParagraphsLastModifiedAt) as? Date
    }

    private func setLocalAutoParagraphsModifiedAt(_ value: Date) {
        defaults.set(value, forKey: UserDefaultsKeys.iCloud.autoParagraphsLastModifiedAt)
    }

    private func listFormattingModifiedAt() -> Date? {
        defaults.object(forKey: UserDefaultsKeys.iCloud.listFormattingLastModifiedAt) as? Date
    }

    private func setLocalListFormattingModifiedAt(_ value: Date) {
        defaults.set(value, forKey: UserDefaultsKeys.iCloud.listFormattingLastModifiedAt)
    }

    private func updateLocalSettingTimestamp(for cloudModifiedAtKey: String, value: Date) {
        switch cloudModifiedAtKey {
        case KeyVoxiCloudKeys.autoParagraphsModifiedAt:
            setLocalAutoParagraphsModifiedAt(value)
        case KeyVoxiCloudKeys.listFormattingModifiedAt:
            setLocalListFormattingModifiedAt(value)
        default:
            break
        }
    }

    private func inferredLocalDictionaryModifiedAt() -> Date? {
        localDictionaryModifiedAt() ?? (dictionaryStore.entries.isEmpty ? nil : now())
    }

    private func inferredLocalAutoParagraphsModifiedAt(defaultValue: Bool) -> Date? {
        autoParagraphsModifiedAt() ?? (appSettings.autoParagraphsEnabled == defaultValue ? nil : now())
    }

    private func inferredLocalListFormattingModifiedAt(defaultValue: Bool) -> Date? {
        listFormattingModifiedAt() ?? (appSettings.listFormattingEnabled == defaultValue ? nil : now())
    }
}
