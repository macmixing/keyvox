import Foundation

@_cdecl("keyvox_engine_configure")
public func configure(_ resources: UnsafePointer<CChar>, _ models: UnsafePointer<CChar>, _ dictionary: UnsafePointer<CChar>, _ runtime: UnsafePointer<CChar>, _ soc: UnsafePointer<CChar>) {
    let resources = URL(fileURLWithPath: String(cString: resources), isDirectory: true)
    let models = URL(fileURLWithPath: String(cString: models), isDirectory: true)
    let dictionary = URL(fileURLWithPath: String(cString: dictionary), isDirectory: true)
    let runtime = URL(fileURLWithPath: String(cString: runtime), isDirectory: true)
    let soc = String(cString: soc)
    Task { @MainActor in
        do {
            if EngineSession.shared == nil {
                EngineSession.shared = try EngineSession(resources: resources, models: models, dictionaryDirectory: dictionary, runtimeDirectory: runtime, socIdentifier: soc)
            }
            EngineSession.shared?.refreshModel()
        } catch { EngineEvent(kind: .failed).send() }
    }
}

@_cdecl("keyvox_engine_transcribe")
public func transcribe(_ path: UnsafePointer<CChar>, _ request: Int64) {
    let path = String(cString: path)
    Task { @MainActor in
        guard let session = EngineSession.shared else { EngineEvent(kind: .failed, request: request).send(); return }
        session.transcribe(path: path, id: request)
    }
}

@_cdecl("keyvox_engine_cancel")
public func cancel() { Task { @MainActor in EngineSession.shared?.cancel() } }

@_cdecl("keyvox_engine_download")
public func download() { Task { @MainActor in EngineSession.shared?.download() } }
