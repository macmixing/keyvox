extension LocalLanguageModelGPUOffloadMode {
    var logLabel: String {
        switch self {
        case .disabled:
            return "disabled"
        case .automatic:
            return "automatic"
        case .allLayers:
            return "allLayers"
        case .layerCount(let layerCount):
            return "layerCount(\(layerCount))"
        }
    }
}
