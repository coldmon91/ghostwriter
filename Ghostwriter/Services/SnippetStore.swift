import Foundation

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []

    init() { load() }

    func load() {
        if let loaded = JSONStore.load([Snippet].self, from: StoragePaths.snippetsURL) {
            snippets = loaded
        } else {
            snippets = Self.defaultSnippets()
            save()
        }
    }

    func save() {
        do {
            try JSONStore.save(snippets, to: StoragePaths.snippetsURL)
        } catch {
            NSLog("SnippetStore.save failed: %@", "\(error)")
        }
    }

    func upsert(_ snippet: Snippet) {
        var s = snippet
        s.updatedAt = Date()
        if let idx = snippets.firstIndex(where: { $0.id == s.id }) {
            snippets[idx] = s
        } else {
            snippets.append(s)
        }
        save()
    }

    func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func incrementUsage(id: UUID) {
        guard let idx = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[idx].usageCount += 1
        snippets[idx].updatedAt = Date()
        save()
    }

    func search(_ query: String) -> [Snippet] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = snippets.sorted { ($0.usageCount, $0.updatedAt) > ($1.usageCount, $1.updatedAt) }
        if q.isEmpty { return base }
        return base.filter { snippet in
            snippet.name.lowercased().contains(q) ||
            snippet.title.lowercased().contains(q) ||
            (snippet.category?.lowercased().contains(q) ?? false)
        }
    }

    static func defaultSnippets() -> [Snippet] {
        [
            Snippet(
                name: "code-review",
                title: "코드 리뷰 요청",
                body: """
                다음 코드를 리뷰해줘.
                언어: {{language}}
                중점 사항: {{focus}}

                ```
                {{code}}
                ```
                """,
                category: "review"
            ),
            Snippet(
                name: "translate",
                title: "번역 요청",
                body: """
                다음 텍스트를 {{target_language}}로 번역해줘. 원문의 톤을 유지해.

                {{text}}
                """,
                category: "translate"
            ),
            Snippet(
                name: "system-prompt",
                title: "시스템 프롬프트 템플릿",
                body: """
                You are {{role}}.

                Goals:
                - {{goal_1}}
                - {{goal_2}}

                Constraints:
                - {{constraint}}
                """,
                category: "prompt"
            )
        ]
    }
}
