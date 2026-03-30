import Foundation
import Combine
import KeyVoxCore

@MainActor
final class AppServiceRegistry {
    static let shared = AppServiceRegistry()

    let appSettings: AppSettingsStore
    let dictionaryStore: DictionaryStore
    let dictationProvider: any DictationProvider
    let activeProviderRouter: SwitchableDictationProvider
    let whisperService: WhisperService
    let parakeetService: ParakeetService
    let weeklyWordStatsStore: WeeklyWordStatsStore
    let weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync
    let iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator
    private var canSwitchActiveProvider: () -> Bool
    private var currentActiveProviderSelection: AppSettingsStore.ActiveDictationProvider
    private var cancellables = Set<AnyCancellable>()
    lazy var transcriptionManager: TranscriptionManager = {
        let manager = TranscriptionManager(
            appSettings: appSettings,
            modelDownloader: .shared,
            audioRecorder: AudioRecorder(),
            serviceRegistry: self,
            postProcessor: TranscriptionPostProcessor()
        )

        canSwitchActiveProvider = { [weak manager] in
            manager?.state == .idle
        }

        return manager
    }()

    init(
        appSettings: AppSettingsStore,
        initialActiveProviderSelection: AppSettingsStore.ActiveDictationProvider,
        dictionaryStore: DictionaryStore,
        dictationProvider: any DictationProvider,
        activeProviderRouter: SwitchableDictationProvider,
        whisperService: WhisperService,
        parakeetService: ParakeetService,
        weeklyWordStatsStore: WeeklyWordStatsStore,
        weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync,
        iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator,
        canSwitchActiveProvider: @escaping () -> Bool = { true }
    ) {
        self.appSettings = appSettings
        self.dictionaryStore = dictionaryStore
        self.dictationProvider = dictationProvider
        self.activeProviderRouter = activeProviderRouter
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.canSwitchActiveProvider = canSwitchActiveProvider
        self.currentActiveProviderSelection = initialActiveProviderSelection
        bindActiveProviderSelection()
        handleActiveProviderSelectionChange(appSettings.activeDictationProvider)
    }

    private init(fileManager: FileManager = .default) {
        let appSupportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KeyVox", isDirectory: true)
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/KeyVox", isDirectory: true)
        let modelLocator = InstalledDictationModelLocator(
            fileManager: fileManager,
            appSupportRootURL: appSupportRoot
        )

        appSettings = .shared
        dictionaryStore = DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: appSupportRoot
        )
        whisperService = WhisperService(
            modelPathResolver: modelLocator.resolvedWhisperModelPath
        )
        parakeetService = ParakeetService(
            modelURLResolver: modelLocator.resolvedParakeetModelDirectoryURL
        )
        activeProviderRouter = SwitchableDictationProvider(initialProvider: whisperService)
        dictationProvider = activeProviderRouter
        weeklyWordStatsStore = WeeklyWordStatsStore()
        weeklyWordStatsCloudSync = WeeklyWordStatsCloudSync(
            weeklyWordStatsStore: weeklyWordStatsStore
        )
        iCloudSyncCoordinator = KeyVoxiCloudSyncCoordinator(
            appSettings: appSettings,
            dictionaryStore: dictionaryStore
        )
        canSwitchActiveProvider = { true }
        currentActiveProviderSelection = .whisper
        bindActiveProviderSelection()
        handleActiveProviderSelectionChange(appSettings.activeDictationProvider)
    }

    private func bindActiveProviderSelection() {
        appSettings.$activeDictationProvider
            .removeDuplicates()
            .sink { [weak self] selection in
                self?.handleActiveProviderSelectionChange(selection)
            }
            .store(in: &cancellables)
    }

    private func handleActiveProviderSelectionChange(_ selection: AppSettingsStore.ActiveDictationProvider) {
        guard selection != currentActiveProviderSelection else { return }

        guard canSwitchActiveProvider() else {
            if appSettings.activeDictationProvider != currentActiveProviderSelection {
                appSettings.activeDictationProvider = currentActiveProviderSelection
            }
            return
        }

        applyActiveProviderSelection(selection)
        currentActiveProviderSelection = selection
    }

    private func applyActiveProviderSelection(_ selection: AppSettingsStore.ActiveDictationProvider) {
        let provider: any DictationProvider = switch selection {
        case .whisper:
            whisperService
        case .parakeet:
            parakeetService
        }

        activeProviderRouter.replaceActiveProvider(with: provider)
    }
}
