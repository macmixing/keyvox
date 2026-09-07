/// Worker-confined ownership keeps model destruction behind any active native call.
final class NativeParakeetSessionOwner {
    private let makeSession: () throws -> any NativeParakeetSession
    private var loaded: (any NativeParakeetSession)?

    init(makeSession: @escaping () throws -> any NativeParakeetSession) {
        self.makeSession = makeSession
    }

    func session() throws -> any NativeParakeetSession {
        if let loaded { return loaded }
        let session = try makeSession()
        loaded = session
        return session
    }

    func close() {
        loaded?.close()
        loaded = nil
    }
}
