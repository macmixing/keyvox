import Foundation
import KeyVoxCore

@MainActor
enum AndroidDictionaryBridge {
    static func publishSnapshot(request: Int64 = 0) {
        publish(request: request, operation: .snapshot, result: .success(()))
    }

    static func add(request: Int64, phrase: String) {
        mutate(request: request, operation: .add) { store in
            try store.add(phrase: phrase)
        }
    }

    static func update(request: Int64, id: UUID, phrase: String) {
        mutate(request: request, operation: .update) { store in
            try store.update(id: id, phrase: phrase)
        }
    }

    static func delete(request: Int64, id: UUID) {
        guard let store = EngineSession.shared?.dictionary else {
            publishUnavailable(request: request, operation: .delete)
            return
        }

        let existedBefore = store.entries.contains { $0.id == id }
        store.delete(id: id)
        let stillExists = store.entries.contains { $0.id == id }
        let failed = existedBefore && stillExists && store.saveErrorMessage != nil

        if failed == false {
            AndroidDictionaryCasingStore.shared.update(entries: store.entries)
        }
        publish(
            request: request,
            operation: .delete,
            result: failed
                ? .failure(DictionaryStoreError.saveFailed)
                : .success(())
        )
    }

    static func clearWarnings(request: Int64) {
        guard let store = EngineSession.shared?.dictionary else {
            publishUnavailable(request: request, operation: .clearWarnings)
            return
        }
        store.clearWarnings()
        publish(request: request, operation: .clearWarnings, result: .success(()))
    }

    private static func mutate(
        request: Int64,
        operation: AndroidDictionaryEvent.Operation,
        action: (DictionaryStore) throws -> Void
    ) {
        guard let store = EngineSession.shared?.dictionary else {
            publishUnavailable(request: request, operation: operation)
            return
        }

        do {
            try action(store)
            AndroidDictionaryCasingStore.shared.update(entries: store.entries)
            publish(request: request, operation: operation, result: .success(()))
        } catch {
            publish(request: request, operation: operation, result: .failure(error))
        }
    }

    private static func publish(
        request: Int64,
        operation: AndroidDictionaryEvent.Operation,
        result: Result<Void, Error>
    ) {
        guard let store = EngineSession.shared?.dictionary else {
            publishUnavailable(request: request, operation: operation)
            return
        }

        let errorMessage: String?
        switch result {
        case .success:
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        AndroidDictionaryEvent(
            request: request,
            operation: operation,
            available: true,
            success: errorMessage == nil,
            entries: store.entries,
            loadWarningMessage: store.loadWarningMessage,
            saveErrorMessage: store.saveErrorMessage,
            errorMessage: errorMessage
        ).send()
    }

    private static func publishUnavailable(
        request: Int64,
        operation: AndroidDictionaryEvent.Operation
    ) {
        AndroidDictionaryEvent(
            request: request,
            operation: operation,
            available: false,
            success: false,
            entries: [],
            loadWarningMessage: nil,
            saveErrorMessage: nil,
            errorMessage: "Dictionary is still loading."
        ).send()
    }
}
