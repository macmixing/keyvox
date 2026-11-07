import Foundation

/// Decides which update prompt the shared prompt panel shows. A prompt that holds
/// the panel keeps it until dismissed; other prompts wait and show afterwards.
struct UpdatePromptPanelQueue {
    private var visiblePromptHoldsPanel = false
    private var queuedPrompt: UpdatePrompt?

    mutating func shouldShow(_ prompt: UpdatePrompt, isPanelVisible: Bool) -> Bool {
        if isPanelVisible, visiblePromptHoldsPanel, prompt.holdsPanelUntilDismissed == false {
            queuedPrompt = prompt
            return false
        }

        visiblePromptHoldsPanel = prompt.holdsPanelUntilDismissed
        return true
    }

    mutating func takeQueuedPrompt() -> UpdatePrompt? {
        visiblePromptHoldsPanel = false
        defer { queuedPrompt = nil }
        return queuedPrompt
    }
}
