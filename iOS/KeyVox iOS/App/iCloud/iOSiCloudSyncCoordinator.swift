import Combine
import Foundation
import KeyVoxCore

protocol iOSiCloudKeyValueStoring: AnyObject {
    var notificationObject: AnyObject? { get }
    func object(forKey key: String) -> Any?
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: iOSiCloudKeyValueStoring {
    var notificationObject: AnyObject? { self }
}

@MainActor
final class iOSiCloudSyncCoordinator {
    private let ubiquitousStore: any iOSiCloudKeyValueStoring
    private let notificationCenter: NotificationCenter
    private let settingsStore: iOSAppSettingsStore
    private let dictionaryStore: DictionaryStore
    private let defaults: UserDefaults
    private let now: () -> Date

    private var cancellables = Set<AnyCancellable>()
    private var externalChangeObserver: NSObjectProtocol?
    private var isApplyingRemoteDictionary = false
    private var isApplyingRemoteTriggerBinding = false
    private var isApplyingRemoteAutoParagraphs = false
    private var isApplyingRemoteListFormatting = false

    init(
        ubiquitousStore: any iOSiCloudKeyValueStoring = NSUbiquitousKeyValueStore.default,
        notificationCenter: NotificationCenter = .default,
        settingsStore: iOSAppSettingsStore,
        dictionaryStore: DictionaryStore,
        defaults: UserDefaults,
        now: @escaping () -> Date = Date.init
    ) {
        self.ubiquitousStore = ubiquitousStore
        self.notificationCenter = notificationCenter
        self.settingsStore = settingsStore
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

        if changedKeys.contains(KeyVoxiCloudKeys.triggerBinding)
            || changedKeys.contains(KeyVoxiCloudKeys.triggerBindingModifiedAt) {
            applyRemoteTriggerBindingIfNewer()
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

        settingsStore.$triggerBinding
            .dropFirst()
            .sink { [weak self] value in
                guard let self, !self.isApplyingRemoteTriggerBinding else { return }
                let modifiedAt = self.now()
                self.setLocalTriggerBindingModifiedAt(modifiedAt)
                self.pushSetting(
                    value.rawValue,
                    valueKey: KeyVoxiCloudKeys.triggerBinding,
                    modifiedAtKey: KeyVoxiCloudKeys.triggerBindingModifiedAt,
                    modifiedAt: modifiedAt
                )
            }
            .store(in: &cancellables)

        settingsStore.$autoParagraphsEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self, !self.isApplyingRemoteAutoParagraphs else { return }
                let modifiedAt = self.now()
                self.setLocalAutoParagraphsModifiedAt(modifiedAt)
                self.pushSetting(
                    value,
                    valueKey: KeyVoxiCloudKeys.autoParagraphsEnabled,
                    modifiedAtKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt,
                    modifiedAt: modifiedAt
                )
            }
            .store(in: &cancellables)

        settingsStore.$listFormattingEnabled
            .dropFirst()
            .sink { [weak self] value in
                guard let self, !self.isApplyingRemoteListFormatting else { return }
                let modifiedAt = self.now()
                self.setLocalListFormattingModifiedAt(modifiedAt)
                self.pushSetting(
                    value,
                    valueKey: KeyVoxiCloudKeys.listFormattingEnabled,
                    modifiedAtKey: KeyVoxiCloudKeys.listFormattingModifiedAt,
                    modifiedAt: modifiedAt
                )
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
        bootstrapTriggerBinding()
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

    private func bootstrapTriggerBinding() {
        bootstrapSetting(
            localValue: settingsStore.triggerBinding.rawValue,
            localModifiedAt: inferredLocalTriggerBindingModifiedAt(defaultValue: iOSAppSettingsStore.TriggerBinding.rightOption.rawValue),
            valueKey: KeyVoxiCloudKeys.triggerBinding,
            modifiedAtKey: KeyVoxiCloudKeys.triggerBindingModifiedAt,
            applyRemote: { [weak self] rawValue, modifiedAt in
                self?.applyRemoteTriggerBinding(rawValue: rawValue, modifiedAt: modifiedAt)
            },
            defaultValue: iOSAppSettingsStore.TriggerBinding.rightOption.rawValue
        )
    }

    private func bootstrapAutoParagraphs() {
        bootstrapSetting(
            localValue: settingsStore.autoParagraphsEnabled,
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
            localValue: settingsStore.listFormattingEnabled,
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

        guard let remoteValue = ubiquitousStore.object(forKey: valueKey) as? Bool else {
            return
        }

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

    private func bootstrapSetting(
        localValue: String,
        localModifiedAt: Date?,
        valueKey: String,
        modifiedAtKey: String,
        applyRemote: (String, Date) -> Void,
        defaultValue: String
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

        guard let remoteValue = ubiquitousStore.object(forKey: valueKey) as? String else {
            return
        }

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
        let localModifiedAt = dictionaryModifiedAt() ?? .distantPast
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
            print("[iCloudSync][iOS] Failed to apply remote dictionary payload: \(error)")
            #endif
        }
    }

    private func applyRemoteTriggerBindingIfNewer() {
        guard
            let remoteModifiedAt = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.triggerBindingModifiedAt) as? Date,
            let remoteValue = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.triggerBinding) as? String
        else {
            return
        }

        let localModifiedAt = triggerBindingModifiedAt() ?? .distantPast
        guard remoteModifiedAt > localModifiedAt else { return }
        applyRemoteTriggerBinding(rawValue: remoteValue, modifiedAt: remoteModifiedAt)
    }

    private func applyRemoteTriggerBinding(rawValue: String, modifiedAt: Date) {
        guard let binding = iOSAppSettingsStore.TriggerBinding(rawValue: rawValue) else {
            #if DEBUG
            print("[iCloudSync][iOS] Ignoring invalid remote trigger binding: \(rawValue)")
            #endif
            return
        }

        isApplyingRemoteTriggerBinding = true
        defer { isApplyingRemoteTriggerBinding = false }

        settingsStore.applyCloudTriggerBinding(binding)
        setLocalTriggerBindingModifiedAt(modifiedAt)
    }

    private func applyRemoteAutoParagraphsIfNewer() {
        guard
            let remoteModifiedAt = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.autoParagraphsModifiedAt) as? Date,
            let remoteValue = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.autoParagraphsEnabled) as? Bool
        else {
            return
        }

        let localModifiedAt = autoParagraphsModifiedAt() ?? .distantPast
        guard remoteModifiedAt > localModifiedAt else { return }
        applyRemoteAutoParagraphs(value: remoteValue, modifiedAt: remoteModifiedAt)
    }

    private func applyRemoteAutoParagraphs(value: Bool, modifiedAt: Date) {
        isApplyingRemoteAutoParagraphs = true
        defer { isApplyingRemoteAutoParagraphs = false }

        settingsStore.applyCloudAutoParagraphsEnabled(value)
        setLocalAutoParagraphsModifiedAt(modifiedAt)
    }

    private func applyRemoteListFormattingIfNewer() {
        guard
            let remoteModifiedAt = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.listFormattingModifiedAt) as? Date,
            let remoteValue = ubiquitousStore.object(forKey: KeyVoxiCloudKeys.listFormattingEnabled) as? Bool
        else {
            return
        }

        let localModifiedAt = listFormattingModifiedAt() ?? .distantPast
        guard remoteModifiedAt > localModifiedAt else { return }
        applyRemoteListFormatting(value: remoteValue, modifiedAt: remoteModifiedAt)
    }

    private func applyRemoteListFormatting(value: Bool, modifiedAt: Date) {
        isApplyingRemoteListFormatting = true
        defer { isApplyingRemoteListFormatting = false }

        settingsStore.applyCloudListFormattingEnabled(value)
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
            print("[iCloudSync][iOS] Failed to encode dictionary payload: \(error)")
            #endif
        }
    }

    private func pushSetting(_ value: Bool, valueKey: String, modifiedAtKey: String, modifiedAt: Date) {
        ubiquitousStore.set(value, forKey: valueKey)
        ubiquitousStore.set(modifiedAt, forKey: modifiedAtKey)
        _ = ubiquitousStore.synchronize()
    }

    private func pushSetting(_ value: String, valueKey: String, modifiedAtKey: String, modifiedAt: Date) {
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
            print("[iCloudSync][iOS] Failed to decode remote dictionary payload: \(error)")
            #endif
            return nil
        }
    }

    private func dictionaryModifiedAt() -> Date? {
        defaults.object(forKey: iOSUserDefaultsKeys.iCloud.dictionaryLastModifiedAt) as? Date
    }

    private func setLocalDictionaryModifiedAt(_ value: Date) {
        defaults.set(value, forKey: iOSUserDefaultsKeys.iCloud.dictionaryLastModifiedAt)
    }

    private func triggerBindingModifiedAt() -> Date? {
        defaults.object(forKey: iOSUserDefaultsKeys.iCloud.triggerBindingLastModifiedAt) as? Date
    }

    private func setLocalTriggerBindingModifiedAt(_ value: Date) {
        defaults.set(value, forKey: iOSUserDefaultsKeys.iCloud.triggerBindingLastModifiedAt)
    }

    private func autoParagraphsModifiedAt() -> Date? {
        defaults.object(forKey: iOSUserDefaultsKeys.iCloud.autoParagraphsLastModifiedAt) as? Date
    }

    private func setLocalAutoParagraphsModifiedAt(_ value: Date) {
        defaults.set(value, forKey: iOSUserDefaultsKeys.iCloud.autoParagraphsLastModifiedAt)
    }

    private func listFormattingModifiedAt() -> Date? {
        defaults.object(forKey: iOSUserDefaultsKeys.iCloud.listFormattingLastModifiedAt) as? Date
    }

    private func setLocalListFormattingModifiedAt(_ value: Date) {
        defaults.set(value, forKey: iOSUserDefaultsKeys.iCloud.listFormattingLastModifiedAt)
    }

    private func updateLocalSettingTimestamp(for cloudModifiedAtKey: String, value: Date) {
        switch cloudModifiedAtKey {
        case KeyVoxiCloudKeys.triggerBindingModifiedAt:
            setLocalTriggerBindingModifiedAt(value)
        case KeyVoxiCloudKeys.autoParagraphsModifiedAt:
            setLocalAutoParagraphsModifiedAt(value)
        case KeyVoxiCloudKeys.listFormattingModifiedAt:
            setLocalListFormattingModifiedAt(value)
        default:
            break
        }
    }

    private func inferredLocalDictionaryModifiedAt() -> Date? {
        dictionaryModifiedAt() ?? (dictionaryStore.entries.isEmpty ? nil : now())
    }

    private func inferredLocalTriggerBindingModifiedAt(defaultValue: String) -> Date? {
        triggerBindingModifiedAt() ?? (settingsStore.triggerBinding.rawValue == defaultValue ? nil : now())
    }

    private func inferredLocalAutoParagraphsModifiedAt(defaultValue: Bool) -> Date? {
        autoParagraphsModifiedAt() ?? (settingsStore.autoParagraphsEnabled == defaultValue ? nil : now())
    }

    private func inferredLocalListFormattingModifiedAt(defaultValue: Bool) -> Date? {
        listFormattingModifiedAt() ?? (settingsStore.listFormattingEnabled == defaultValue ? nil : now())
    }
}
