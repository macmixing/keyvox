import Foundation
import UniformTypeIdentifiers
import UIKit

enum KeyVoxShareImageItemLoader {
    static func loadOCRText(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        do {
            KeyVoxShareContentExtractorDiagnostics.log("Attempting generic image item load.")
            if let imageItem = try await KeyVoxShareItemProviderLoader.loadItem(
                from: provider,
                typeIdentifier: UTType.image.identifier
            ) {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Loaded generic image item type=\(String(describing: type(of: imageItem)))."
                )
                if let recognizedText = try recognizeText(fromImageCarrier: imageItem) {
                    return recognizedText
                }
            }

            if let image = try await loadObjectImage(from: provider) {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Loaded UIImage-backed share image size=\(Int(image.size.width))x\(Int(image.size.height))."
                )
                return try KeyVoxShareOCRPipeline.recognizeText(in: image)
            }

            KeyVoxShareContentExtractorDiagnostics.log("Attempting file-backed image OCR load.")
            do {
                if let fileURL = try await KeyVoxShareItemProviderLoader.loadFileRepresentation(
                    from: provider,
                    typeIdentifier: UTType.image.identifier
                ) {
                    KeyVoxShareContentExtractorDiagnostics.log("Loaded file-backed image at \(fileURL.path).")
                    return try KeyVoxShareOCRPipeline.recognizeText(at: fileURL)
                }
                KeyVoxShareContentExtractorDiagnostics.log(
                    "File-backed image load returned nil URL; falling back to data representation."
                )
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "File-backed image load failed: \(error.localizedDescription); falling back to data representation."
                )
            }

            let data = try await KeyVoxShareItemProviderLoader.loadDataRepresentation(
                from: provider,
                typeIdentifier: UTType.image.identifier
            )
            KeyVoxShareContentExtractorDiagnostics.log("Loaded in-memory image data bytes=\(data.count).")
            return try KeyVoxShareOCRPipeline.recognizeText(in: data)
        } catch {
            KeyVoxShareContentExtractorDiagnostics.log("Image OCR load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func loadObjectImage(from provider: NSItemProvider) async throws -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            KeyVoxShareContentExtractorDiagnostics.log(
                "Provider cannot load UIImage directly; continuing to file-backed OCR."
            )
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: UIImage.self) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: image as? UIImage)
            }
        }
    }

    private static func recognizeText(fromImageCarrier item: NSSecureCoding) throws -> String? {
        if let image = item as? UIImage {
            return try KeyVoxShareOCRPipeline.recognizeText(in: image)
        }

        if let url = item as? URL {
            let persistentURL = try KeyVoxShareItemProviderLoader.makePersistentCopy(of: url)
            defer {
                try? FileManager.default.removeItem(at: persistentURL.deletingLastPathComponent())
            }
            KeyVoxShareContentExtractorDiagnostics.log("Recognizing text from generic item URL \(persistentURL.path).")
            return try KeyVoxShareOCRPipeline.recognizeText(at: persistentURL)
        }

        if let data = item as? Data {
            do {
                if let recognizedText = try KeyVoxShareOCRPipeline.recognizeText(in: data) {
                    return recognizedText
                }
            } catch {
                KeyVoxShareContentExtractorDiagnostics.log(
                    "Data-backed OCR failed: \(error.localizedDescription); attempting property-list fallback."
                )
            }

            if let plistPayloadText = try recognizeTextFromPropertyListData(data) {
                return plistPayloadText
            }
        }

        if let dictionary = item as? NSDictionary,
           let recognizedText = try recognizeText(fromPropertyListObject: dictionary) {
            return recognizedText
        }

        if let array = item as? NSArray {
            for element in array {
                if let recognizedText = try recognizeText(fromPropertyListObject: element) {
                    return recognizedText
                }
            }
        }

        return nil
    }

    private static func recognizeTextFromPropertyListData(_ data: Data) throws -> String? {
        guard data.starts(with: [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74]) else {
            return nil
        }

        KeyVoxShareContentExtractorDiagnostics.log("Inspecting property-list-backed image payload bytes=\(data.count).")
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try recognizeText(fromPropertyListObject: propertyList)
    }

    private static func recognizeText(fromPropertyListObject object: Any) throws -> String? {
        if let image = object as? UIImage {
            return try KeyVoxShareOCRPipeline.recognizeText(in: image)
        }

        if let data = object as? Data {
            return try KeyVoxShareOCRPipeline.recognizeText(in: data)
        }

        if let url = object as? URL {
            let persistentURL = try KeyVoxShareItemProviderLoader.makePersistentCopy(of: url)
            defer {
                try? FileManager.default.removeItem(at: persistentURL.deletingLastPathComponent())
            }
            return try KeyVoxShareOCRPipeline.recognizeText(at: persistentURL)
        }

        if let dictionary = object as? [AnyHashable: Any] {
            for value in dictionary.values {
                if let recognizedText = try recognizeText(fromPropertyListObject: value) {
                    return recognizedText
                }
            }
            return nil
        }

        if let array = object as? [Any] {
            for value in array {
                if let recognizedText = try recognizeText(fromPropertyListObject: value) {
                    return recognizedText
                }
            }
        }

        return nil
    }

}

enum KeyVoxShareImageOCRExtractor {
    static func extractText(from items: [NSExtensionItem]) async -> String {
        var segments: [String] = []

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await KeyVoxShareImageItemLoader.loadOCRText(from: provider) {
                    segments.append(text)
                }
            }
        }

        return KeyVoxShareTextSupport.joinedText(from: segments)
    }
}
