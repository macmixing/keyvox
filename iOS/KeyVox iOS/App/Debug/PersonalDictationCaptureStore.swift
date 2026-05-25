import Foundation
import SQLite3

enum PersonalDictationCaptureRating: String, Codable {
    case unrated
    case good
    case bad
}

struct PersonalDictationCaptureVariantContext {
    let captureID: String
    let styleIdentifier: String
    let sourceText: String
    let visibleText: String
    let rawDictationText: String?
    let baseText: String?
    let postprocessedOutputText: String?
    let metadata: [String: String]
}

struct PersonalDictationCaptureVariantState {
    let variantID: String
    let rating: PersonalDictationCaptureRating
}

struct PersonalDictationCaptureRearmedVariant {
    let variantID: String
    let visibleText: String
    let styleIdentifier: String
}

final class PersonalDictationCaptureStore {
    static let shared = PersonalDictationCaptureStore()

    private enum Constants {
        static let databaseFileName = "personal-dictation-captures.sqlite"
        static let jsonExportFileName = "personal-dictation-captures.json"
    }

    private let queue = DispatchQueue(label: "com.cueit.keyvox.personal-capture-store")
    private let databaseURL: URL?
    private var db: OpaquePointer?

    private init(
        fileManager: FileManager = .default,
        appGroupID: String = KeyVoxIPCBridge.appGroupID
    ) {
        databaseURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(Constants.databaseFileName)
        open()
        createTablesIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    func databaseFileURL() -> URL? {
        queue.sync {
            databaseURL
        }
    }

    func upsertVariant(_ context: PersonalDictationCaptureVariantContext) -> PersonalDictationCaptureVariantState? {
        queue.sync {
            guard let db else { return nil }
            if let existing = variantState(
                captureID: context.captureID,
                styleIdentifier: context.styleIdentifier,
                sourceText: context.sourceText,
                visibleText: context.visibleText
            ) {
                return existing
            }

            let trace = latestTrace(
                styleIdentifier: context.styleIdentifier,
                sourceText: context.sourceText,
                postprocessedOutputText: context.postprocessedOutputText ?? context.visibleText
            )
            let variantID = UUID().uuidString
            let metadataJSON = metadataJSON(context.metadata)
            let now = Date().timeIntervalSince1970
            let sql = """
            INSERT INTO capture_variants (
                variant_id,
                capture_id,
                style_identifier,
                source_text,
                visible_text,
                raw_dictation_text,
                base_text,
                model_output_text,
                postprocessed_output_text,
                rating,
                created_at,
                rated_at,
                metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            bindText(stmt, 1, variantID)
            bindText(stmt, 2, context.captureID)
            bindText(stmt, 3, context.styleIdentifier)
            bindText(stmt, 4, context.sourceText)
            bindText(stmt, 5, context.visibleText)
            bindOptionalText(stmt, 6, context.rawDictationText)
            bindOptionalText(stmt, 7, context.baseText)
            bindOptionalText(stmt, 8, trace?.modelOutputText)
            bindOptionalText(stmt, 9, context.postprocessedOutputText ?? trace?.postprocessedOutputText)
            bindText(stmt, 10, PersonalDictationCaptureRating.unrated.rawValue)
            sqlite3_bind_double(stmt, 11, now)
            bindOptionalText(stmt, 12, metadataJSON)
            let didInsert = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard didInsert else { return nil }
            return PersonalDictationCaptureVariantState(variantID: variantID, rating: .unrated)
        }
    }

    func recordRewriteTrace(
        styleIdentifier: String,
        sourceText: String,
        modelOutputText: String?,
        postprocessedOutputText: String,
        metadata: [String: String]
    ) {
        queue.sync {
            guard let db else { return }
            let sql = """
            INSERT INTO rewrite_traces (
                style_identifier,
                source_text,
                model_output_text,
                postprocessed_output_text,
                metadata_json,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            bindText(stmt, 1, styleIdentifier)
            bindText(stmt, 2, sourceText)
            bindOptionalText(stmt, 3, modelOutputText)
            bindText(stmt, 4, postprocessedOutputText)
            bindOptionalText(stmt, 5, metadataJSON(metadata))
            sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func rateVariant(variantID: String, rating: PersonalDictationCaptureRating) -> PersonalDictationCaptureVariantState? {
        guard rating != .unrated else {
            return clearRating(variantID: variantID)
        }

        return queue.sync {
            guard let db else { return nil }
            let sql = "UPDATE capture_variants SET rating = ?, rated_at = ? WHERE variant_id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            bindText(stmt, 1, rating.rawValue)
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            bindText(stmt, 3, variantID)
            let didUpdate = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
            sqlite3_finalize(stmt)
            guard didUpdate else { return nil }
            return PersonalDictationCaptureVariantState(variantID: variantID, rating: rating)
        }
    }

    func clearRating(variantID: String) -> PersonalDictationCaptureVariantState? {
        queue.sync {
            guard let db else { return nil }
            let sql = "UPDATE capture_variants SET rating = ?, rated_at = NULL WHERE variant_id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            bindText(stmt, 1, PersonalDictationCaptureRating.unrated.rawValue)
            bindText(stmt, 2, variantID)
            let didUpdate = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(db) > 0
            sqlite3_finalize(stmt)
            guard didUpdate else { return nil }
            return PersonalDictationCaptureVariantState(variantID: variantID, rating: .unrated)
        }
    }

    func latestUnratedVariant() -> PersonalDictationCaptureRearmedVariant? {
        queue.sync {
            guard let db else { return nil }
            let sql = """
            SELECT variant_id, visible_text, style_identifier
            FROM capture_variants
            WHERE rating = ?
            ORDER BY created_at DESC
            LIMIT 1
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            bindText(stmt, 1, PersonalDictationCaptureRating.unrated.rawValue)
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  let variantID = columnText(stmt, 0),
                  let visibleText = columnText(stmt, 1),
                  let styleIdentifier = columnText(stmt, 2) else {
                return nil
            }
            return PersonalDictationCaptureRearmedVariant(
                variantID: variantID,
                visibleText: visibleText,
                styleIdentifier: styleIdentifier
            )
        }
    }

    func exportRatedJSONFile() -> URL? {
        queue.sync {
            guard let data = ratedJSONData() else { return nil }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(Constants.jsonExportFileName)
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }
    }

    private func open() {
        guard let databaseURL else { return }
        let parentURL = databaseURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true
        )
        sqlite3_open(databaseURL.path, &db)
    }

    private func createTablesIfNeeded() {
        queue.sync {
            guard let db else { return }
            execute("""
            CREATE TABLE IF NOT EXISTS capture_variants (
                variant_id TEXT PRIMARY KEY,
                capture_id TEXT NOT NULL,
                style_identifier TEXT NOT NULL,
                source_text TEXT NOT NULL,
                visible_text TEXT NOT NULL,
                raw_dictation_text TEXT,
                base_text TEXT,
                model_output_text TEXT,
                postprocessed_output_text TEXT,
                rating TEXT NOT NULL,
                created_at REAL NOT NULL,
                rated_at REAL,
                metadata_json TEXT
            )
            """, db: db)
            execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_capture_variant_identity
            ON capture_variants(capture_id, style_identifier, source_text, visible_text)
            """, db: db)
            execute("""
            CREATE INDEX IF NOT EXISTS idx_capture_variant_rating_created
            ON capture_variants(rating, created_at DESC)
            """, db: db)
            execute("""
            CREATE TABLE IF NOT EXISTS rewrite_traces (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                style_identifier TEXT NOT NULL,
                source_text TEXT NOT NULL,
                model_output_text TEXT,
                postprocessed_output_text TEXT NOT NULL,
                metadata_json TEXT,
                created_at REAL NOT NULL
            )
            """, db: db)
            execute("""
            CREATE INDEX IF NOT EXISTS idx_rewrite_trace_lookup
            ON rewrite_traces(style_identifier, source_text, postprocessed_output_text, created_at DESC)
            """, db: db)
        }
    }

    private func execute(_ sql: String, db: OpaquePointer) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func variantState(
        captureID: String,
        styleIdentifier: String,
        sourceText: String,
        visibleText: String
    ) -> PersonalDictationCaptureVariantState? {
        guard let db else { return nil }
        let sql = """
        SELECT variant_id, rating
        FROM capture_variants
        WHERE capture_id = ? AND style_identifier = ? AND source_text = ? AND visible_text = ?
        LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        bindText(stmt, 1, captureID)
        bindText(stmt, 2, styleIdentifier)
        bindText(stmt, 3, sourceText)
        bindText(stmt, 4, visibleText)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let variantID = columnText(stmt, 0),
              let ratingText = columnText(stmt, 1),
              let rating = PersonalDictationCaptureRating(rawValue: ratingText) else {
            return nil
        }
        return PersonalDictationCaptureVariantState(variantID: variantID, rating: rating)
    }

    private func latestTrace(
        styleIdentifier: String,
        sourceText: String,
        postprocessedOutputText: String
    ) -> (modelOutputText: String?, postprocessedOutputText: String)? {
        guard let db else { return nil }
        let sql = """
        SELECT model_output_text, postprocessed_output_text
        FROM rewrite_traces
        WHERE style_identifier = ? AND source_text = ? AND postprocessed_output_text = ?
        ORDER BY created_at DESC
        LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        bindText(stmt, 1, styleIdentifier)
        bindText(stmt, 2, sourceText)
        bindText(stmt, 3, postprocessedOutputText)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let postprocessedOutputText = columnText(stmt, 1) else {
            return nil
        }
        return (
            modelOutputText: columnText(stmt, 0),
            postprocessedOutputText: postprocessedOutputText
        )
    }

    private func ratedJSONData() -> Data? {
        guard let db else { return nil }
        let sql = """
        SELECT variant_id, capture_id, style_identifier, source_text, visible_text,
               raw_dictation_text, base_text, model_output_text, postprocessed_output_text,
               rating, created_at, rated_at, metadata_json
        FROM capture_variants
        WHERE rating != ?
        ORDER BY created_at ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        bindText(stmt, 1, PersonalDictationCaptureRating.unrated.rawValue)
        defer { sqlite3_finalize(stmt) }

        var records: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var record: [String: Any] = [
                "variant_id": columnText(stmt, 0) ?? "",
                "capture_id": columnText(stmt, 1) ?? "",
                "style_identifier": columnText(stmt, 2) ?? "",
                "source_text": columnText(stmt, 3) ?? "",
                "visible_text": columnText(stmt, 4) ?? "",
                "rating": columnText(stmt, 9) ?? "",
                "created_at": sqlite3_column_double(stmt, 10)
            ]
            if let value = columnText(stmt, 5) { record["raw_dictation_text"] = value }
            if let value = columnText(stmt, 6) { record["base_text"] = value }
            if let value = columnText(stmt, 7) { record["model_output_text"] = value }
            if let value = columnText(stmt, 8) { record["postprocessed_output_text"] = value }
            if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
                record["rated_at"] = sqlite3_column_double(stmt, 11)
            }
            if let value = columnText(stmt, 12) { record["metadata_json"] = value }
            records.append(record)
        }

        let payload: [String: Any] = [
            "exported_at": Date().timeIntervalSince1970,
            "records": records
        ]
        return try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func metadataJSON(_ metadata: [String: String]) -> String? {
        guard !metadata.isEmpty,
              let data = try? JSONSerialization.data(
                withJSONObject: metadata,
                options: [.sortedKeys]
              ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
    sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
}

private func bindOptionalText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
    guard let value else {
        sqlite3_bind_null(stmt, index)
        return
    }
    bindText(stmt, index, value)
}

private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
          let text = sqlite3_column_text(stmt, index) else {
        return nil
    }
    return String(cString: text)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
