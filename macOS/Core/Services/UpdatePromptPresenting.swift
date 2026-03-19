import Foundation

@MainActor
protocol UpdatePromptPresenting {
    func show(prompt: UpdatePrompt)
}
