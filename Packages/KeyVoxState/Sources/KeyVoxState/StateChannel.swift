/// A current value and independent, bounded update streams for main-actor state.
/// Slow consumers receive the latest state rather than an unbounded event backlog.
@MainActor
public final class StateChannel<Value: Sendable> {
    private var currentValue: Value
    private var nextSubscriberID: UInt64 = 0
    private var subscribers: [UInt64: AsyncStream<Value>.Continuation] = [:]

    public init(_ value: Value) {
        currentValue = value
    }

    public var value: Value {
        get { currentValue }
        set {
            currentValue = newValue
            for subscriber in subscribers.values {
                subscriber.yield(newValue)
            }
        }
    }

    public var values: AsyncStream<Value> {
        let id = nextSubscriberID
        nextSubscriberID &+= 1
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            subscribers[id] = continuation
            continuation.yield(currentValue)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.subscribers.removeValue(forKey: id) }
            }
        }
    }

    deinit {
        for subscriber in subscribers.values {
            subscriber.finish()
        }
    }
}
