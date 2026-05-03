import Foundation
import SQLite3

final class SQLiteStore: @unchecked Sendable {
    private let url: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "LocalBird.SQLiteStore")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) throws {
        self.url = url
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try open()
        try migrate()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func saveSettings(_ settings: LocalBirdSettings) throws {
        let data = try encoder.encode(settings)
        try setSetting(key: "settings", value: String(decoding: data, as: UTF8.self))
    }

    func loadSettings() throws -> LocalBirdSettings {
        guard let value = try getSetting(key: "settings"),
              let data = value.data(using: .utf8) else {
            return .defaults
        }
        return try decoder.decode(LocalBirdSettings.self, from: data)
    }

    func insertCapture(_ capture: CaptureRecord) throws {
        try run(
            """
            INSERT OR REPLACE INTO captures (
              id, captured_at, active_app_bundle_id, active_app_name, window_title,
              display_id, screenshot_path, ocr_text, perceptual_hash, is_duplicate,
              privacy_redacted, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            [
                capture.id,
                iso(capture.capturedAt),
                capture.activeAppBundleID,
                capture.activeAppName,
                capture.windowTitle,
                capture.displayID,
                capture.screenshotPath,
                capture.ocrText,
                capture.perceptualHash,
                capture.isDuplicate ? 1 : 0,
                capture.privacyRedacted ? 1 : 0,
                iso(capture.createdAt)
            ]
        )
    }

    func recentCaptures(limit: Int) throws -> [CaptureRecord] {
        try queryCaptures(
            "SELECT * FROM captures ORDER BY captured_at DESC LIMIT ?;",
            [limit]
        )
    }

    func captures(on day: Date, calendar: Calendar = .current) throws -> [CaptureRecord] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try captures(from: start, to: end)
    }

    func captures(from start: Date, to end: Date) throws -> [CaptureRecord] {
        try queryCaptures(
            "SELECT * FROM captures WHERE captured_at >= ? AND captured_at < ? ORDER BY captured_at ASC;",
            [iso(start), iso(end)]
        )
    }

    func latestCaptureHash() throws -> String? {
        try queue.sync {
            let sql = "SELECT perceptual_hash FROM captures ORDER BY captured_at DESC LIMIT 1;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            if sqlite3_step(statement) == SQLITE_ROW {
                return text(statement, 0)
            }
            return nil
        }
    }

    func insertActivityBlocks(_ blocks: [ActivityBlock]) throws {
        try run("DELETE FROM activity_blocks;", [])
        for block in blocks {
            let apps = try String(decoding: encoder.encode(block.dominantApps), as: UTF8.self)
            let titles = try String(decoding: encoder.encode(block.dominantWindowTitles), as: UTF8.self)
            let reps = try String(decoding: encoder.encode(block.representativeCaptureIDs), as: UTF8.self)
            try run(
                """
                INSERT OR REPLACE INTO activity_blocks (
                  id, start_time, end_time, dominant_apps, dominant_window_titles,
                  summary_hint, representative_capture_ids, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                [block.id, iso(block.startTime), iso(block.endTime), apps, titles, block.summaryHint, reps, iso(block.createdAt)]
            )
        }
    }

    func activityBlocks() throws -> [ActivityBlock] {
        try queue.sync {
            var statement: OpaquePointer?
            let sql = "SELECT * FROM activity_blocks ORDER BY start_time ASC;"
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            var blocks: [ActivityBlock] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let apps = try decodeStringArray(text(statement, 3) ?? "[]")
                let titles = try decodeStringArray(text(statement, 4) ?? "[]")
                let reps = try decodeStringArray(text(statement, 6) ?? "[]")
                blocks.append(ActivityBlock(
                    id: text(statement, 0) ?? UUID().uuidString,
                    startTime: date(text(statement, 1)) ?? Date(),
                    endTime: date(text(statement, 2)) ?? Date(),
                    dominantApps: apps,
                    dominantWindowTitles: titles,
                    summaryHint: text(statement, 5) ?? "",
                    representativeCaptureIDs: reps,
                    createdAt: date(text(statement, 7)) ?? Date()
                ))
            }
            return blocks
        }
    }

    func insertRoutineRun(_ run: RoutineRun) throws {
        try runSQL(
            """
            INSERT OR REPLACE INTO routine_runs (
              id, routine_type, started_at, completed_at, input_packet_path,
              output_markdown_path, backend, status, error_message, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            [
                run.id,
                run.routineType.rawValue,
                iso(run.startedAt),
                run.completedAt.map(iso),
                run.inputPacketPath,
                run.outputMarkdownPath,
                run.backend,
                run.status.rawValue,
                run.errorMessage,
                iso(run.createdAt)
            ]
        )
    }

    func latestRoutineRun(type: RoutineType) throws -> RoutineRun? {
        try queryRoutineRuns(
            "SELECT * FROM routine_runs WHERE routine_type = ? ORDER BY started_at DESC LIMIT 1;",
            [type.rawValue]
        ).first
    }

    func deleteAllData() throws {
        try run("DELETE FROM captures;", [])
        try run("DELETE FROM activity_blocks;", [])
        try run("DELETE FROM routine_runs;", [])
    }

    private func open() throws {
        let code = sqlite3_open(url.path, &db)
        guard code == SQLITE_OK else {
            throw sqliteError()
        }
    }

    private func migrate() throws {
        try run(
            """
            CREATE TABLE IF NOT EXISTS captures (
              id TEXT PRIMARY KEY,
              captured_at TEXT NOT NULL,
              active_app_bundle_id TEXT,
              active_app_name TEXT,
              window_title TEXT,
              display_id TEXT,
              screenshot_path TEXT NOT NULL,
              ocr_text TEXT,
              perceptual_hash TEXT,
              is_duplicate INTEGER DEFAULT 0,
              privacy_redacted INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            );
            """,
            []
        )
        try run(
            """
            CREATE TABLE IF NOT EXISTS activity_blocks (
              id TEXT PRIMARY KEY,
              start_time TEXT NOT NULL,
              end_time TEXT NOT NULL,
              dominant_apps TEXT,
              dominant_window_titles TEXT,
              summary_hint TEXT,
              representative_capture_ids TEXT,
              created_at TEXT NOT NULL
            );
            """,
            []
        )
        try run(
            """
            CREATE TABLE IF NOT EXISTS routine_runs (
              id TEXT PRIMARY KEY,
              routine_type TEXT NOT NULL,
              started_at TEXT NOT NULL,
              completed_at TEXT,
              input_packet_path TEXT NOT NULL,
              output_markdown_path TEXT,
              backend TEXT NOT NULL,
              status TEXT NOT NULL,
              error_message TEXT,
              created_at TEXT NOT NULL
            );
            """,
            []
        )
        try run(
            """
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            """,
            []
        )
    }

    private func setSetting(key: String, value: String) throws {
        try run(
            "INSERT OR REPLACE INTO settings (key, value, updated_at) VALUES (?, ?, ?);",
            [key, value, iso(Date())]
        )
    }

    private func getSetting(key: String) throws -> String? {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT value FROM settings WHERE key = ?;", -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            bind(key, to: statement, index: 1)
            if sqlite3_step(statement) == SQLITE_ROW {
                return text(statement, 0)
            }
            return nil
        }
    }

    private func queryCaptures(_ sql: String, _ values: [Any?]) throws -> [CaptureRecord] {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            bind(values, to: statement)
            var captures: [CaptureRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                captures.append(CaptureRecord(
                    id: text(statement, 0) ?? UUID().uuidString,
                    capturedAt: date(text(statement, 1)) ?? Date(),
                    activeAppBundleID: text(statement, 2),
                    activeAppName: text(statement, 3),
                    windowTitle: text(statement, 4),
                    displayID: text(statement, 5),
                    screenshotPath: text(statement, 6) ?? "",
                    ocrText: text(statement, 7),
                    perceptualHash: text(statement, 8),
                    isDuplicate: sqlite3_column_int(statement, 9) == 1,
                    privacyRedacted: sqlite3_column_int(statement, 10) == 1,
                    createdAt: date(text(statement, 11)) ?? Date()
                ))
            }
            return captures
        }
    }

    private func queryRoutineRuns(_ sql: String, _ values: [Any?]) throws -> [RoutineRun] {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            bind(values, to: statement)
            var runs: [RoutineRun] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                runs.append(RoutineRun(
                    id: text(statement, 0) ?? UUID().uuidString,
                    routineType: RoutineType(rawValue: text(statement, 1) ?? "") ?? .daily,
                    startedAt: date(text(statement, 2)) ?? Date(),
                    completedAt: date(text(statement, 3)),
                    inputPacketPath: text(statement, 4) ?? "",
                    outputMarkdownPath: text(statement, 5),
                    backend: text(statement, 6) ?? "",
                    status: RoutineStatus(rawValue: text(statement, 7) ?? "") ?? .pending,
                    errorMessage: text(statement, 8),
                    createdAt: date(text(statement, 9)) ?? Date()
                ))
            }
            return runs
        }
    }

    private func run(_ sql: String, _ values: [Any?]) throws {
        try runSQL(sql, values)
    }

    private func runSQL(_ sql: String, _ values: [Any?]) throws {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError()
            }
            defer { sqlite3_finalize(statement) }
            bind(values, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw sqliteError()
            }
        }
    }

    private func bind(_ values: [Any?], to statement: OpaquePointer?) {
        for (offset, value) in values.enumerated() {
            bind(value, to: statement, index: Int32(offset + 1))
        }
    }

    private func bind(_ value: Any?, to statement: OpaquePointer?, index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        if let value = value as? Int {
            sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        } else if let value = value as? Bool {
            sqlite3_bind_int(statement, index, value ? 1 : 0)
        } else if let value = value as? String {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_text(statement, index, "\(value)", -1, SQLITE_TRANSIENT)
        }
    }

    private func sqliteError() -> LocalBirdError {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error"
        return .sqlite(message)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }

    private func decodeStringArray(_ string: String) throws -> [String] {
        guard let data = string.data(using: .utf8) else { return [] }
        return try decoder.decode([String].self, from: data)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
