import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var content: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isFavorite: Bool = false

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if firstLine.count <= 100 { return firstLine }
        return String(firstLine.prefix(100)) + "…"
    }

    var characterCount: Int { content.count }
}
