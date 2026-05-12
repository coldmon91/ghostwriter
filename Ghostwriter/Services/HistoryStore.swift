import Foundation
import GRDB

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let dbQueue: DatabaseQueue?
    private let maxRows: Int = 1000

    init() {
        self.dbQueue = Self.openDatabase()
        migrateFromJSONIfNeeded()
        reload()
    }

    // MARK: - Public API (preserves prior behavior so callers don't change)

    func reload() {
        guard let dbQueue else { return }
        do {
            let rows = try dbQueue.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT id, content, createdAt, updatedAt, isFavorite
                    FROM history
                    ORDER BY isFavorite DESC, updatedAt DESC
                    LIMIT \(maxRows)
                """)
            }
            entries = rows.compactMap(Self.entry(from:))
        } catch {
            NSLog("HistoryStore.reload failed: %@", "\(error)")
        }
    }

    /// Upsert: if id exists update content/updatedAt, else insert new row.
    @discardableResult
    func upsert(id: UUID?, content: String) -> UUID? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let id { delete(id: id) }
            return nil
        }
        guard let dbQueue else { return id }
        let now = Date()
        do {
            let resolvedID: UUID = try dbQueue.write { db in
                if let id, try Self.exists(db: db, id: id) {
                    try db.execute(sql: "UPDATE history SET content=?, updatedAt=? WHERE id=?",
                                   arguments: [content, now.timeIntervalSince1970, id.uuidString])
                    return id
                }
                let newID = id ?? UUID()
                try db.execute(sql: """
                    INSERT INTO history (id, content, createdAt, updatedAt, isFavorite)
                    VALUES (?, ?, ?, ?, 0)
                """, arguments: [newID.uuidString, content,
                                 now.timeIntervalSince1970, now.timeIntervalSince1970])
                return newID
            }
            reload()
            return resolvedID
        } catch {
            NSLog("HistoryStore.upsert failed: %@", "\(error)")
            return id
        }
    }

    func delete(id: UUID) {
        guard let dbQueue else { return }
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM history WHERE id=?",
                               arguments: [id.uuidString])
            }
            reload()
        } catch {
            NSLog("HistoryStore.delete failed: %@", "\(error)")
        }
    }

    func deleteAll() {
        guard let dbQueue else { return }
        do {
            try dbQueue.write { db in try db.execute(sql: "DELETE FROM history") }
            reload()
        } catch {
            NSLog("HistoryStore.deleteAll failed: %@", "\(error)")
        }
    }

    func toggleFavorite(id: UUID) {
        guard let dbQueue else { return }
        do {
            try dbQueue.write { db in
                try db.execute(sql: """
                    UPDATE history
                    SET isFavorite = CASE isFavorite WHEN 1 THEN 0 ELSE 1 END,
                        updatedAt = ?
                    WHERE id = ?
                """, arguments: [Date().timeIntervalSince1970, id.uuidString])
            }
            reload()
        } catch {
            NSLog("HistoryStore.toggleFavorite failed: %@", "\(error)")
        }
    }

    /// Full-text + substring fallback search. Empty query returns all entries.
    func search(_ query: String) -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        guard let dbQueue else { return [] }

        let pattern = Self.fts5Pattern(from: q)
        do {
            let rows: [Row] = try dbQueue.read { db in
                if let pattern {
                    return try Row.fetchAll(db, sql: """
                        SELECT history.id, history.content, history.createdAt,
                               history.updatedAt, history.isFavorite
                        FROM history
                        JOIN history_fts ON history.rowid = history_fts.rowid
                        WHERE history_fts MATCH ?
                        ORDER BY history.isFavorite DESC, bm25(history_fts), history.updatedAt DESC
                        LIMIT \(self.maxRows)
                    """, arguments: [pattern])
                }
                // Fallback: LIKE substring (used when query has no tokens FTS5 can match).
                let like = "%\(q.replacingOccurrences(of: "%", with: "\\%"))%"
                return try Row.fetchAll(db, sql: """
                    SELECT id, content, createdAt, updatedAt, isFavorite
                    FROM history
                    WHERE content LIKE ? ESCAPE '\\'
                    ORDER BY isFavorite DESC, updatedAt DESC
                    LIMIT \(self.maxRows)
                """, arguments: [like])
            }
            return rows.compactMap(Self.entry(from:))
        } catch {
            NSLog("HistoryStore.search failed: %@", "\(error)")
            return []
        }
    }

    /// Removes entries older than retentionDays (favorites kept).
    func purgeOld(retentionDays: Int) {
        guard retentionDays > 0, let dbQueue else { return }
        let cutoff = Date().timeIntervalSince1970 - Double(retentionDays) * 86_400
        do {
            try dbQueue.write { db in
                try db.execute(sql: """
                    DELETE FROM history WHERE isFavorite = 0 AND updatedAt < ?
                """, arguments: [cutoff])
            }
            reload()
        } catch {
            NSLog("HistoryStore.purgeOld failed: %@", "\(error)")
        }
    }

    // MARK: - Database setup

    private static func openDatabase() -> DatabaseQueue? {
        do {
            var config = Configuration()
            config.foreignKeysEnabled = true
            let queue = try DatabaseQueue(path: StoragePaths.historyDBURL.path, configuration: config)
            try queue.write { db in
                try db.execute(sql: """
                    CREATE TABLE IF NOT EXISTS history (
                        id TEXT PRIMARY KEY NOT NULL,
                        content TEXT NOT NULL,
                        createdAt REAL NOT NULL,
                        updatedAt REAL NOT NULL,
                        isFavorite INTEGER NOT NULL DEFAULT 0
                    )
                """)
                try db.execute(sql: """
                    CREATE INDEX IF NOT EXISTS history_updated_idx ON history(updatedAt DESC)
                """)
                try db.execute(sql: """
                    CREATE VIRTUAL TABLE IF NOT EXISTS history_fts USING fts5(
                        content,
                        content='history',
                        content_rowid='rowid',
                        tokenize='unicode61 remove_diacritics 2'
                    )
                """)
                try db.execute(sql: """
                    CREATE TRIGGER IF NOT EXISTS history_ai AFTER INSERT ON history BEGIN
                        INSERT INTO history_fts(rowid, content) VALUES (new.rowid, new.content);
                    END
                """)
                try db.execute(sql: """
                    CREATE TRIGGER IF NOT EXISTS history_ad AFTER DELETE ON history BEGIN
                        INSERT INTO history_fts(history_fts, rowid, content)
                        VALUES ('delete', old.rowid, old.content);
                    END
                """)
                try db.execute(sql: """
                    CREATE TRIGGER IF NOT EXISTS history_au AFTER UPDATE ON history BEGIN
                        INSERT INTO history_fts(history_fts, rowid, content)
                        VALUES ('delete', old.rowid, old.content);
                        INSERT INTO history_fts(rowid, content) VALUES (new.rowid, new.content);
                    END
                """)
            }
            return queue
        } catch {
            NSLog("HistoryStore.openDatabase failed: %@", "\(error)")
            return nil
        }
    }

    /// Imports old history.json into SQLite once; renames the file to *.bak on success
    /// so it isn't reapplied. If something goes wrong the JSON is preserved untouched.
    private func migrateFromJSONIfNeeded() {
        guard let dbQueue else { return }
        let fm = FileManager.default
        let jsonURL = StoragePaths.historyURL
        let bakURL = StoragePaths.historyJSONBackupURL
        guard fm.fileExists(atPath: jsonURL.path) else { return }

        // If a sentinel backup already exists, skip — migration already happened or
        // user manually preserved a backup.
        if fm.fileExists(atPath: bakURL.path) {
            // Still tidy up — remove the live JSON so the migration check stops firing.
            try? fm.removeItem(at: jsonURL)
            return
        }

        guard let oldEntries = JSONStore.load([HistoryEntry].self, from: jsonURL) else {
            NSLog("HistoryStore.migrate: failed to decode history.json")
            return
        }

        do {
            try dbQueue.write { db in
                for e in oldEntries {
                    try db.execute(sql: """
                        INSERT OR IGNORE INTO history (id, content, createdAt, updatedAt, isFavorite)
                        VALUES (?, ?, ?, ?, ?)
                    """, arguments: [
                        e.id.uuidString, e.content,
                        e.createdAt.timeIntervalSince1970,
                        e.updatedAt.timeIntervalSince1970,
                        e.isFavorite ? 1 : 0
                    ])
                }
            }
            try fm.moveItem(at: jsonURL, to: bakURL)
            NSLog("HistoryStore.migrate: imported %d entries from history.json", oldEntries.count)
        } catch {
            NSLog("HistoryStore.migrate failed: %@", "\(error)")
        }
    }

    // MARK: - Helpers

    private static func entry(from row: Row) -> HistoryEntry? {
        guard
            let idStr: String = row["id"],
            let id = UUID(uuidString: idStr),
            let content: String = row["content"]
        else { return nil }
        let createdAt: Double = row["createdAt"] ?? 0
        let updatedAt: Double = row["updatedAt"] ?? createdAt
        let isFavorite: Int = row["isFavorite"] ?? 0
        return HistoryEntry(
            id: id,
            content: content,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            isFavorite: isFavorite != 0
        )
    }

    private static func exists(db: Database, id: UUID) throws -> Bool {
        try Bool.fetchOne(db, sql: "SELECT 1 FROM history WHERE id=?",
                          arguments: [id.uuidString]) ?? false
    }

    /// Build an FTS5 MATCH pattern from a free-form query. Tokens are escaped and joined
    /// with implicit AND. Returns nil if no usable tokens remain.
    private static func fts5Pattern(from raw: String) -> String? {
        // Split on whitespace; drop empties; keep alphanumerics and unicode letters.
        let tokens = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        let escaped = tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" + "*" }
        return escaped.joined(separator: " ")
    }
}
