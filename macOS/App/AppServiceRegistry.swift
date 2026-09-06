import Foundation
import Combine
import KeyVoxCore
import KeyVoxPromotions

@MainActor
final class AppServiceRegistry {
    static let shared = AppServiceRegistry()

    let appSettings: AppSettingsStore
    let dictionaryStore: DictionaryStore
    let dictationProvider: any DictationProvider
    let activeProviderRouter: SwitchableDictationProvider
    let whisperService: WhisperService
    let parakeetService: ParakeetService
    let localRewriteModelManager: MacLocalRewriteModelManager
    let vibesCoordinator: MacVibesCoordinator
    let weeklyWordStatsStore: WeeklyWordStatsStore
    let weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync
    let iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator
    let promotionCenter: PromotionCenter
    private var canSwitchActiveProvider: () -> Bool
    private var currentActiveProviderSelection: AppSettingsStore.ActiveDictationProvider
    private var cancellables = Set<AnyCancellable>()
    lazy var transcriptionManager: TranscriptionManager = {
        let audioRecorder = AudioRecorder()
        let manager = TranscriptionManager(
            appSettings: appSettings,
            modelDownloader: .shared,
            audioRecorder: audioRecorder,
            serviceRegistry: self,
            vibesCoordinator: vibesCoordinator,
            postProcessor: TranscriptionPostProcessor()
        )
        audioRecorder.prepareRecordingSession()

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
        localRewriteModelManager: MacLocalRewriteModelManager? = nil,
        vibesCoordinator: MacVibesCoordinator? = nil,
        weeklyWordStatsStore: WeeklyWordStatsStore,
        weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync,
        iCloudSyncCoordinator: KeyVoxiCloudSyncCoordinator,
        promotionCenter: PromotionCenter? = nil,
        canSwitchActiveProvider: @escaping () -> Bool = { true }
    ) {
        self.appSettings = appSettings
        self.dictionaryStore = dictionaryStore
        self.dictationProvider = dictationProvider
        self.activeProviderRouter = activeProviderRouter
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        let resolvedLocalRewriteModelManager = localRewriteModelManager ?? MacLocalRewriteModelManager(refreshOnInit: false)
        self.localRewriteModelManager = resolvedLocalRewriteModelManager
        self.vibesCoordinator = vibesCoordinator ?? Self.makeVibesCoordinator(
            appSettings: appSettings,
            localRewriteModelManager: resolvedLocalRewriteModelManager
        )
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.promotionCenter = promotionCenter ?? Self.makePromotionCenter(defaults: .standard)
        self.canSwitchActiveProvider = canSwitchActiveProvider
        self.currentActiveProviderSelection = initialActiveProviderSelection
        whisperService.updateLanguage(appSettings.whisperDictationLanguage)
        bindActiveProviderSelection()
        bindWhisperLanguageSelection()
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
        localRewriteModelManager = MacLocalRewriteModelManager(
            fileManager: fileManager,
            appSupportRootURL: appSupportRoot
        )
        vibesCoordinator = Self.makeVibesCoordinator(
            appSettings: appSettings,
            localRewriteModelManager: localRewriteModelManager
        )
        activeProviderRouter = SwitchableDictationProvider(initialProvider: whisperService)
        dictationProvider = activeProviderRouter
        weeklyWordStatsStore = WeeklyWordStatsStore()
        weeklyWordStatsCloudSync = WeeklyWordStatsCloudSync(
            weeklyWordStatsStore: weeklyWordStatsStore
        )
        iCloudSyncCoordinator = KeyVoxiCloudSyncCoordinator(
            appSettings: appSettings,
            dictionaryStore: dictionaryStore,
            hasExistingLocalInstallation: appSettings.hasCompletedOnboarding,
            forceFreshDictionaryInstall: MacRuntimeFlags.forceFreshDictionaryInstall
        )
        promotionCenter = Self.makePromotionCenter(defaults: .standard)
        ModelDownloader.shared.postInstallPreparation = { [weak parakeetService] modelID in
            guard modelID == .parakeetTdtV3 else { return }
            try Task.checkCancellation()
            await parakeetService?.preloadIfNeeded()
        }
        canSwitchActiveProvider = { true }
        currentActiveProviderSelection = .whisper
        whisperService.updateLanguage(appSettings.whisperDictationLanguage)
        bindActiveProviderSelection()
        bindWhisperLanguageSelection()
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

    private func bindWhisperLanguageSelection() {
        appSettings.$whisperDictationLanguage
            .removeDuplicates()
            .sink { [weak self] language in
                self?.whisperService.updateLanguage(language)
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

    private static func makeVibesCoordinator(
        appSettings: AppSettingsStore,
        localRewriteModelManager: MacLocalRewriteModelManager
    ) -> MacVibesCoordinator {
        let localRewriteInferenceService = localRewriteInferenceService(for: localRewriteModelManager)
        let localStyleRewriteTextTransformer = MacLocalStyleRewriteTextTransformer(
            inferenceService: localRewriteInferenceService
        )
        localRewriteModelManager.onDidInvalidateInstalledModel = { [weak localRewriteInferenceService] in
            Task { @MainActor in
                await localRewriteInferenceService?.unload()
            }
        }
        return MacVibesCoordinator(
            appSettings: appSettings,
            textTransformer: localStyleRewriteTextTransformer,
            isModelReady: { [weak localRewriteModelManager] in
                localRewriteModelManager?.isModelReady() ?? false
            },
            releaseResources: { reason in
                await localStyleRewriteTextTransformer.releaseResources(reason: reason)
            }
        )
    }

    private static func localRewriteInferenceService(
        for localRewriteModelManager: MacLocalRewriteModelManager
    ) -> MacLocalRewriteInferenceService {
        MacLocalRewriteInferenceService(
            modelURLProvider: { [weak localRewriteModelManager] in
                localRewriteModelManager?.installedModelURL()
            },
            adapterURLProvider: { [weak localRewriteModelManager] adapter in
                switch adapter {
                case .polished:
                    return localRewriteModelManager?.polishedLoRAURL()
                case .casual:
                    return localRewriteModelManager?.casualLoRAURL()
                }
            }
        )
    }

    private static func makePromotionCenter(defaults: UserDefaults) -> PromotionCenter {
        PromotionCenter(
            platform: .macOS,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            defaults: defaults,
            usesBundledManifest: MacRuntimeFlags.useLocalPromotionManifest,
            previewCampaignID: MacRuntimeFlags.promotionPreviewCampaignID
        )
    }
}
