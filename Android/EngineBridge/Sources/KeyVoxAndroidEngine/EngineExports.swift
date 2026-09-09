import Foundation

@_cdecl("keyvox_engine_configure")
public func configure(_ resources: UnsafePointer<CChar>, _ models: UnsafePointer<CChar>, _ dictionary: UnsafePointer<CChar>, _ runtime: UnsafePointer<CChar>, _ soc: UnsafePointer<CChar>) {
    let resources = URL(fileURLWithPath: String(cString: resources), isDirectory: true)
    let models = URL(fileURLWithPath: String(cString: models), isDirectory: true)
    let dictionary = URL(fileURLWithPath: String(cString: dictionary), isDirectory: true)
    let runtime = URL(fileURLWithPath: String(cString: runtime), isDirectory: true)
    let soc = String(cString: soc)
    AndroidDictionaryCasingStore.shared.configure(directory: dictionary)
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

@_cdecl("keyvox_engine_compose")
public func compose(
    _ transcriptBytes: UnsafePointer<UInt8>,
    _ transcriptLength: Int32,
    _ precedingBytes: UnsafePointer<UInt8>?,
    _ precedingLength: Int32,
    _ precedingTextIsTruncated: Bool,
    _ followingBytes: UnsafePointer<UInt8>?,
    _ followingLength: Int32,
    _ followingTextIsTruncated: Bool,
    _ outputLength: UnsafeMutablePointer<Int32>
) -> UnsafeMutablePointer<UInt8>? {
    guard transcriptLength >= 0,
          precedingLength >= 0,
          followingLength >= 0,
          let transcript = decodeUTF8(transcriptBytes, count: transcriptLength),
          let precedingText = decodeOptionalUTF8(precedingBytes, count: precedingLength),
          let followingText = decodeOptionalUTF8(followingBytes, count: followingLength),
          let data = try? JSONEncoder().encode(AndroidTextComposition.compose(
              transcript: transcript,
              precedingText: precedingText,
              precedingTextIsTruncated: precedingTextIsTruncated,
              followingText: followingText,
              followingTextIsTruncated: followingTextIsTruncated
          )),
          data.count <= Int(Int32.max) else {
        outputLength.pointee = 0
        return nil
    }

    let output = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
    data.copyBytes(to: output, count: data.count)
    outputLength.pointee = Int32(data.count)
    return output
}

@_cdecl("keyvox_engine_free_bytes")
public func freeBytes(_ bytes: UnsafeMutablePointer<UInt8>?) {
    bytes?.deallocate()
}

private func decodeUTF8(_ bytes: UnsafePointer<UInt8>, count: Int32) -> String? {
    String(bytes: UnsafeBufferPointer(start: bytes, count: Int(count)), encoding: .utf8)
}

private func decodeOptionalUTF8(
    _ bytes: UnsafePointer<UInt8>?,
    count: Int32
) -> String?? {
    guard let bytes else { return .some(nil) }
    return decodeUTF8(bytes, count: count).map(Optional.some)
}
