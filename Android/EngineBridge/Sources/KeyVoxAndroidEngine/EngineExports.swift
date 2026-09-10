import Foundation

@_cdecl("keyvox_engine_configure")
public func configure(_ resources: UnsafePointer<CChar>, _ models: UnsafePointer<CChar>, _ dictionary: UnsafePointer<CChar>, _ runtime: UnsafePointer<CChar>, _ soc: UnsafePointer<CChar>, _ appVersion: UnsafePointer<CChar>) {
    let resources = URL(fileURLWithPath: String(cString: resources), isDirectory: true)
    let models = URL(fileURLWithPath: String(cString: models), isDirectory: true)
    let dictionary = URL(fileURLWithPath: String(cString: dictionary), isDirectory: true)
    let runtime = URL(fileURLWithPath: String(cString: runtime), isDirectory: true)
    let soc = String(cString: soc)
    let appVersion = String(cString: appVersion)
    AndroidDictionaryCasingStore.shared.configure(directory: dictionary)
    Task { @MainActor in
        do {
            if EngineSession.shared == nil {
                EngineSession.shared = try EngineSession(resources: resources, models: models, dictionaryDirectory: dictionary, runtimeDirectory: runtime, socIdentifier: soc)
            }
            AndroidDictionaryBridge.publishSnapshot()
            try AndroidPromotionCoordinator.install(resources: resources, appVersion: appVersion)
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

@_cdecl("keyvox_promotions_configure")
public func configurePromotions(
    _ appVersion: UnsafePointer<CChar>,
    _ usesBundledManifest: Bool,
    _ previewCampaignID: UnsafePointer<CChar>?
) {
    let appVersion = String(cString: appVersion)
    let previewCampaignID = previewCampaignID.map(String.init(cString:))
    Task { @MainActor in
        AndroidPromotionCoordinator.configurePreview(
            appVersion: appVersion,
            usesBundledManifest: usesBundledManifest,
            previewCampaignID: previewCampaignID
        )
    }
}

@_cdecl("keyvox_promotions_refresh")
public func refreshPromotions() {
    Task { @MainActor in AndroidPromotionCoordinator.shared?.refresh() }
}

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

@_cdecl("keyvox_dictionary_list")
public func listDictionary(_ request: Int64) {
    Task { @MainActor in AndroidDictionaryBridge.publishSnapshot(request: request) }
}

@_cdecl("keyvox_dictionary_add")
public func addDictionaryEntry(
    _ request: Int64,
    _ phraseBytes: UnsafePointer<UInt8>,
    _ phraseLength: Int32
) {
    guard let phrase = decodeUTF8(phraseBytes, count: phraseLength) else { return }
    Task { @MainActor in AndroidDictionaryBridge.add(request: request, phrase: phrase) }
}

@_cdecl("keyvox_dictionary_update")
public func updateDictionaryEntry(
    _ request: Int64,
    _ identifier: UnsafePointer<CChar>,
    _ phraseBytes: UnsafePointer<UInt8>,
    _ phraseLength: Int32
) {
    guard let id = UUID(uuidString: String(cString: identifier)),
          let phrase = decodeUTF8(phraseBytes, count: phraseLength) else { return }
    Task { @MainActor in AndroidDictionaryBridge.update(request: request, id: id, phrase: phrase) }
}

@_cdecl("keyvox_dictionary_delete")
public func deleteDictionaryEntry(_ request: Int64, _ identifier: UnsafePointer<CChar>) {
    guard let id = UUID(uuidString: String(cString: identifier)) else { return }
    Task { @MainActor in AndroidDictionaryBridge.delete(request: request, id: id) }
}

@_cdecl("keyvox_dictionary_clear_warnings")
public func clearDictionaryWarnings(_ request: Int64) {
    Task { @MainActor in AndroidDictionaryBridge.clearWarnings(request: request) }
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
