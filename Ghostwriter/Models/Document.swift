import Foundation

struct Document: Identifiable, Equatable {
    let id: UUID
    var content: String
    var historyEntryID: UUID?     // links to its persisted HistoryEntry
    var createdAt: Date

    init(id: UUID = UUID(), content: String = "", historyEntryID: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.historyEntryID = historyEntryID
        self.createdAt = createdAt
    }

    var displayTitle: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Untitled"
        if firstLine.count <= 30 { return firstLine }
        return String(firstLine.prefix(30)) + "…"
    }
}

struct PersistedTabState: Codable {
    var documents: [PersistedDocument]
    var selectedID: UUID?
}

struct PersistedDocument: Codable {
    var id: UUID
    var content: String
    var historyEntryID: UUID?
    var createdAt: Date
}
