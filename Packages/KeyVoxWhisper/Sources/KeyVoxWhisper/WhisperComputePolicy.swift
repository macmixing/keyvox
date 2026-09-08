/// Selects runtime compute resources without changing the speech model or decoder.
public enum WhisperComputePolicy: Sendable, Equatable {
    /// Uses available runtime acceleration, subject to existing Apple platform safeguards.
    /// Non-Apple context initialization retries once on CPU if GPU initialization fails.
    case automatic
    /// Disables GPU submission. Platform model accelerators such as Core ML are separate.
    case gpuDisabled
}
