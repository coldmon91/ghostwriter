import SwiftUI

/// Floating snippet picker that appears when `/` is typed in the editor.
struct SnippetPopup: View {
    let query: String
    let snippets: [Snippet]
    let selectedIndex: Int
    var onSelect: (Snippet) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "command")
                    .font(.caption)
                Text("/" + query)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text("\(snippets.count) 항목")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            if snippets.isEmpty {
                Text("일치하는 스니펫 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                                SnippetPopupRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex
                                ) { onSelect(snippet) }
                                .id(snippet.id)
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                    .onChange(of: selectedIndex) { _, newValue in
                        guard snippets.indices.contains(newValue) else { return }
                        withAnimation(.linear(duration: 0.05)) {
                            proxy.scrollTo(snippets[newValue].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 8)
    }
}

private struct SnippetPopupRow: View {
    let snippet: Snippet
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var hovered = false

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if hovered { return Color.accentColor.opacity(0.15) }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("/" + snippet.name)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(snippet.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(snippet.body.prefix(60))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onSelect() }
    }
}
