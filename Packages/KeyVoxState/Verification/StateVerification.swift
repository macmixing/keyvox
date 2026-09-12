import KeyVoxState
#if canImport(Combine)
import Combine
#endif

/// Framework-independent checks executed by both the test suite and device probe.
@MainActor
public enum StateVerification {
    struct Failure: Error { let check: String }

    public static func verify() async throws {
        try await multicast()
        try await latestValue()
        try await destruction()
        try await cancellation()
        try await propertyWrapper()
    }

    private static func require(_ condition: Bool, _ check: String) throws {
        if !condition { throw Failure(check: check) }
    }

    private static func multicast() async throws {
        let channel = StateChannel(1)
        var first = channel.values.makeAsyncIterator()
        var second = channel.values.makeAsyncIterator()
        try require(await first.next() == channel.value, "first initial value")
        try require(await second.next() == channel.value, "second initial value")
        channel.value = 2
        try require(await first.next() == channel.value, "first update")
        try require(await second.next() == channel.value, "second update")
    }

    private static func latestValue() async throws {
        let channel = StateChannel(0)
        var iterator = channel.values.makeAsyncIterator()
        channel.value = 1
        channel.value = 2
        try require(await iterator.next() == channel.value, "bounded latest state")
    }

    private static func destruction() async throws {
        var channel: StateChannel<Int>? = StateChannel(0)
        var iterator = channel!.values.makeAsyncIterator()
        _ = await iterator.next()
        channel = nil
        try require(await iterator.next() == nil, "finish on destruction")
    }

    private static func cancellation() async throws {
        let channel = StateChannel(0)
        let stream = channel.values
        var surviving = channel.values.makeAsyncIterator()
        _ = await surviving.next()
        let task = Task { @MainActor in
            for await _ in stream {}
        }
        task.cancel()
        await task.value
        channel.value = 1
        try require(await surviving.next() == channel.value, "subscriber cancellation isolation")
    }

    private static func propertyWrapper() async throws {
        let owner = StateOwner()
        #if canImport(Combine)
        var published: [Int] = []
        var changeCount = 0
        let valueSubscription = owner.$value.sink { published.append($0) }
        let objectSubscription = owner.objectWillChange.sink { changeCount += 1 }
        owner.update()
        try require(published == [0, owner.value], "Apple projected publisher")
        try require(changeCount == 1, "Apple object observation")
        withExtendedLifetime((valueSubscription, objectSubscription)) {}
        #else
        var iterator = owner.$value.values.makeAsyncIterator()
        try require(await iterator.next() == owner.value, "property initial state")
        owner.update()
        try require(await iterator.next() == owner.value, "property updated state")
        try require(owner.$value.value == owner.value, "read-only current state")
        #endif
    }
}

@MainActor
private final class StateOwner: StatePublishing {
    @StateValue private(set) var value = 0
    func update() { value += 1 }
}
