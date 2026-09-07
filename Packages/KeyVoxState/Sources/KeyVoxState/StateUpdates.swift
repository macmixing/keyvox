/// Read-only access to a state owner's current value and subsequent updates.
@MainActor
public struct StateUpdates<Value: Sendable> {
    private let channel: StateChannel<Value>

    init(channel: StateChannel<Value>) {
        self.channel = channel
    }

    public var value: Value { channel.value }
    public var values: AsyncStream<Value> { channel.values }
}
