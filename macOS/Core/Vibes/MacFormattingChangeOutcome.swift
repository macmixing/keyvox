import KeyVoxCore

struct MacFormattingChangeOutcome: Equatable {
    let didApply: Bool
    let effectiveState: DictationDeterministicState?
}
