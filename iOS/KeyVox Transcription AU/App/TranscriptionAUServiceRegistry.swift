import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite
import KeyVoxVibesAdapters

/// The composition root for the Transcription AU extension's process. It builds the same
/// dictation services the containing app builds, on the models, dictionary, and settings in the
/// shared container.
@MainActor
final class TranscriptionAUServiceRegistry {
    let settingsDefaults: UserDefaults
    /// The dictionary as of the current dictation; the app can change it between dictations.
    private(set) var dictionaryStore: DictionaryStore
    let activeProviderRouter: SwitchableDictationProvider
    let styleRewritePipelineCoordinator: StyleRewritePipelineCoordinator
    let selectedVibe: TranscriptionAUSelectedVibe

    private let fileManager: FileManager
    private var activeProviderSelection: AppSettingsStore.ActiveDictationProvider?
    private let whisperService: WhisperService
    private let parakeetService: ParakeetService
    private let postProcessorLoading: Task<TranscriptionPostProcessor, Never>

    init(fileManager: FileManager = .default) {
        let settingsDefaults = SharedPaths.appGroupUserDefaults() ?? .standard
        let modelLocator = InstalledDictationModelLocator(
            fileManager: fileManager,
            modelsDirectoryURL: SharedPaths.modelsDirectoryURL(fileManager: fileManager)
        )
        let linguisticAnalyzer = DictationLinguisticAnalyzer.make(
            portableResourceDirectory: { Self.containingAppBundleURL }
        )
        let whisperService = WhisperService(
            modelPathResolver: modelLocator.resolvedWhisperModelPath,
            linguisticAnalyzer: linguisticAnalyzer
        )
        let parakeetService = ParakeetService(modelURLResolver: modelLocator.resolvedParakeetModelDirectoryURL)
        let localRewriteModelLocator = InstalledLocalRewriteModelLocator(fileManager: fileManager)
        let localRewriteInferenceService = LocalRewriteInferenceService(
            modelURLProvider: {
                localRewriteModelLocator.installedModelURL()
            },
            adapterURLProvider: { adapter in
                switch adapter {
                case .polished:
                    return localRewriteModelLocator.adapterURL(for: .polished)
                case .casual:
                    return localRewriteModelLocator.adapterURL(for: .casual)
                }
            }
        )
        let localStyleRewriteTextTransformer = LocalStyleRewriteTextTransformer(
            inferenceService: localRewriteInferenceService,
            linguisticAnalyzer: linguisticAnalyzer
        )
        let selectedVibe = TranscriptionAUSelectedVibe()

        self.fileManager = fileManager
        self.settingsDefaults = settingsDefaults
        self.selectedVibe = selectedVibe
        self.dictionaryStore = Self.loadDictionaryStore(fileManager: fileManager)
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.activeProviderRouter = SwitchableDictationProvider(initialProvider: whisperService)
        // Building the post-processor loads its language data, which takes long enough to hold
        // up the start of a dictation, so it loads off the main thread while the user speaks.
        self.postProcessorLoading = Task.detached(priority: .userInitiated) {
            TranscriptionPostProcessor(linguisticAnalyzer: linguisticAnalyzer)
        }
        self.styleRewritePipelineCoordinator = StyleRewritePipelineCoordinator(
            selectedStyleProvider: { selectedVibe.style },
            artifactStore: StyleRewriteLatestArtifactStore(defaults: settingsDefaults),
            textTransformer: localStyleRewriteTextTransformer,
            releaseResources: { reason in
                await localStyleRewriteTextTransformer.releaseResources(reason: reason)
            }
        )
    }

    var postProcessor: TranscriptionPostProcessor {
        get async {
            await postProcessorLoading.value
        }
    }

    /// Makes the provider and language saved in the app's dictation settings the active ones
    /// and reads the dictionary as it is now.
    func applySavedDictationSettings() {
        dictionaryStore = Self.loadDictionaryStore(fileManager: fileManager)
        whisperService.updateLanguage(
            AppSettingsStore.resolvedWhisperDictationLanguage(from: settingsDefaults)
        )

        let selection = AppSettingsStore.resolvedActiveDictationProvider(from: settingsDefaults)
        guard selection != activeProviderSelection else {
            // A model freed when the keyboard went away loads again while the user speaks.
            if activeProviderRouter.isModelReady {
                activeProviderRouter.warmup()
            }
            return
        }

        let activeProvider: any DictationProvider = switch selection {
        case .whisper:
            whisperService
        case .parakeet:
            parakeetService
        }
        activeProviderRouter.replaceActiveProvider(with: activeProvider, warmNewProviderIfReady: true)
        activeProviderSelection = selection
    }

    /// Frees the dictation models; the next dictation loads its model again.
    func unloadDictationModels() {
        whisperService.unloadModel()
        parakeetService.unloadModel()
    }

    /// Records a finished dictation's words the way the containing app does.
    func recordSpokenWords(from text: String) {
        WeeklyWordStatsStore(defaults: settingsDefaults).recordSpokenWords(from: text)
        AppReviewRequestStore(defaults: settingsDefaults).recordSuccessfulDictation()
    }

    private static func loadDictionaryStore(fileManager: FileManager) -> DictionaryStore {
        DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: SharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)
                ?? SharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager)
        )
    }

    /// The containing app's bundle, two levels above this extension's own.
    private nonisolated static var containingAppBundleURL: URL {
        Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}
