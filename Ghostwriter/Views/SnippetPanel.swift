import SwiftUI

struct SnippetPanel: View {
    @ObservedObject var store: SnippetStore
    @State private var query = ""
    @State private var editing: Snippet?
    @State private var showCreate = false

    var onInsert: (Snippet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text")
                Text("스니펫")
                    .font(.headline)
                Spacer()
                Button {
                    editing = Snippet(name: "new-snippet", title: "새 스니펫", body: "")
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("새 스니펫 추가")
            }
            .padding(.horizontal, 8)

            TextField("검색", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)

            List {
                ForEach(store.search(query)) { snippet in
                    SnippetRow(snippet: snippet,
                               onInsert: { onInsert(snippet) },
                               onEdit: { editing = snippet; showCreate = true },
                               onDelete: { store.delete(id: snippet.id) })
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 120)
        }
        .sheet(isPresented: $showCreate) {
            if let snippet = editing {
                SnippetEditor(snippet: snippet) { saved in
                    store.upsert(saved)
                    showCreate = false
                    editing = nil
                } onCancel: {
                    showCreate = false
                    editing = nil
                }
            }
        }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onInsert: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("/" + snippet.name)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(snippet.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let category = snippet.category, !category.isEmpty {
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onInsert() }
        .contextMenu {
            Button("삽입") { onInsert() }
            Button("편집") { onEdit() }
            Divider()
            Button("삭제", role: .destructive) { onDelete() }
        }
    }
}

struct SnippetEditor: View {
    @State var snippet: Snippet
    var onSave: (Snippet) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("스니펫 편집")
                .font(.title2)
            HStack {
                Text("이름").frame(width: 60, alignment: .leading)
                TextField("slash command", text: $snippet.name)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("제목").frame(width: 60, alignment: .leading)
                TextField("표시명", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("분류").frame(width: 60, alignment: .leading)
                TextField("category", text: Binding(
                    get: { snippet.category ?? "" },
                    set: { snippet.category = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading) {
                Text("본문")
                TextEditor(text: $snippet.body)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.3))
            }
            HStack {
                Spacer()
                Button("취소") { onCancel() }
                Button("저장") { onSave(snippet) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 480)
    }
}
