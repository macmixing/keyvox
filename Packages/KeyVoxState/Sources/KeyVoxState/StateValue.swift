#if canImport(Combine)
import Combine

// Preserve Apple projected publishers and ObservableObject synthesis exactly.
public typealias StateValue<Value> = Published<Value>
public typealias StatePublishing = ObservableObject
#else
@MainActor
public protocol StatePublishing: AnyObject {}

@MainActor
@propertyWrapper
public struct StateValue<Value: Sendable> {
    private let channel: StateChannel<Value>

    public init(wrappedValue: Value) {
        channel = StateChannel(wrappedValue)
    }

    public var wrappedValue: Value {
        get { channel.value }
        nonmutating set { channel.value = newValue }
    }

    public var projectedValue: StateUpdates<Value> { StateUpdates(channel: channel) }
}
#endif
