import Foundation

public enum KeyVoxCoreResourceText {
    public static var pronunciationLicensesText: String? {
        text(
            fileName: "LICENSES",
            fileExtension: "md",
            subdirectory: "Pronunciation"
        )
    }

    public static var pronunciationSourcesLockText: String? {
        text(
            fileName: "sources.lock",
            fileExtension: "json",
            subdirectory: "Pronunciation"
        )
    }

    public static func text(
        fileName: String,
        fileExtension: String,
        subdirectory: String? = nil
    ) -> String? {
        guard let url = resourceURL(
            fileName: fileName,
            fileExtension: fileExtension,
            subdirectory: subdirectory
        ) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func resourceURL(
        fileName: String,
        fileExtension: String,
        subdirectory: String?
    ) -> URL? {
        if let subdirectory {
            return Bundle.module.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ) ?? Bundle.module.url(
                forResource: fileName,
                withExtension: fileExtension
            )
        }

        return Bundle.module.url(
            forResource: fileName,
            withExtension: fileExtension
        )
    }
}
