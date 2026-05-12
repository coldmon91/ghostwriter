import SwiftUI

struct HistoryPanel: View {
    @ObservedObject var store: HistoryStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var onOpen: (HistoryEntry) -> Void
    var onCopy: (HistoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock")
                Text("이력")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("모두 삭제", role: .destructive) {
                        store.deleteAll()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            .padding(.horizontal, 8)

            TextField("검색", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
                .focused($searchFocused)

            List {
                ForEach(store.search(query)) { entry in
                    HistoryRow(entry: entry,
                               onOpen: { onOpen(entry) },
                               onCopy: { onCopy(entry) },
                               onToggleFavorite: { store.toggleFavorite(id: entry.id) },
                               onDelete: { store.delete(id: entry.id) })
                }
            }
            .listStyle(.sidebar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ghostwriterFocusHistorySearch)) { _ in
            searchFocused = true
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                }
                Text(entry.preview.isEmpty ? "(빈 텍스트)" : entry.preview)
                    .lineLimit(1)
            }
            HStack {
                Text(Self.dateFormatter.string(from: entry.updatedAt))
                Spacer()
                Text("\(entry.characterCount)자")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
        .contextMenu {
            Button("새 탭에 열기") { onOpen() }
            Button("복사") { onCopy() }
            Button(entry.isFavorite ? "즐겨찾기 해제" : "즐겨찾기") { onToggleFavorite() }
            Divider()
            Button("삭제", role: .destructive) { onDelete() }
        }
    }
}
