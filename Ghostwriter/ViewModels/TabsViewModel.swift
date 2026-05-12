import Foundation
import Combine

@MainActor
final class TabsViewModel: ObservableObject {
    @Published private(set) var documents: [Document] = []
    @Published var selectedID: UUID?

    /// One EditorViewModel per document, keyed by document ID.
    @Published private(set) var editorVMs: [UUID: EditorViewModel] = [:]

    private let aiService: AIService
    private let historyStore: HistoryStore
    private let settingsStore: SettingsStore
    private var saveStateTask: Task<Void, Never>?

    init(aiService: AIService, historyStore: HistoryStore, settingsStore: SettingsStore = .shared) {
        self.aiService = aiService
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        restoreOrCreate()
    }

    var selectedDocument: Document? {
        guard let id = selectedID else { return nil }
        return documents.first(where: { $0.id == id })
    }

    var selectedEditorVM: EditorViewModel? {
        guard let id = selectedID else { return nil }
        return editorVMs[id]
    }

    func newTab(content: String = "") {
        let doc = Document(content: content)
        documents.append(doc)
        let vm = EditorViewModel(
            id: doc.id,
            initialContent: content,
            historyEntryID: nil,
            aiService: aiService,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        editorVMs[doc.id] = vm
        selectedID = doc.id
        scheduleSaveState()
    }

    func closeTab(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: idx)
        editorVMs[id] = nil
        if selectedID == id {
            if documents.isEmpty {
                newTab()
            } else {
                let nextIdx = max(0, idx - 1)
                selectedID = documents[min(nextIdx, documents.count - 1)].id
            }
        }
        scheduleSaveState()
    }

    func selectNext() {
        guard !documents.isEmpty, let id = selectedID,
              let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        let next = (idx + 1) % documents.count
        selectedID = documents[next].id
    }

    func selectPrevious() {
        guard !documents.isEmpty, let id = selectedID,
              let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        let prev = (idx - 1 + documents.count) % documents.count
        selectedID = documents[prev].id
    }

    func select(id: UUID) {
        guard documents.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    /// Open content from history into a new tab.
    func openInNewTab(historyEntryID: UUID, content: String) {
        // If already open, switch to that tab.
        if let existing = documents.first(where: { $0.historyEntryID == historyEntryID }) {
            selectedID = existing.id
            return
        }
        let doc = Document(content: content, historyEntryID: historyEntryID)
        documents.append(doc)
        let vm = EditorViewModel(
            id: doc.id,
            initialContent: content,
            historyEntryID: historyEntryID,
            aiService: aiService,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        editorVMs[doc.id] = vm
        selectedID = doc.id
        scheduleSaveState()
    }

    /// Sync the current content from the EditorViewModel back to its Document.
    func syncCurrent() {
        guard let id = selectedID, let vm = editorVMs[id],
              let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].content = vm.content
        documents[idx].historyEntryID = vm.historyEntryID
    }

    // MARK: - Persistence

    func scheduleSaveState() {
        saveStateTask?.cancel()
        saveStateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if Task.isCancelled { return }
            self?.saveStateNow()
        }
    }

    func saveStateNow() {
        syncCurrent()
        let persisted = PersistedTabState(
            documents: documents.map {
                PersistedDocument(
                    id: $0.id,
                    content: $0.content,
                    historyEntryID: $0.historyEntryID,
                    createdAt: $0.createdAt
                )
            },
            selectedID: selectedID
        )
        TabsStateStore.save(persisted)
    }

    private func restoreOrCreate() {
        if let state = TabsStateStore.load(), !state.documents.isEmpty {
            documents = state.documents.map {
                Document(id: $0.id, content: $0.content, historyEntryID: $0.historyEntryID, createdAt: $0.createdAt)
            }
            for doc in documents {
                let vm = EditorViewModel(
                    id: doc.id,
                    initialContent: doc.content,
                    historyEntryID: doc.historyEntryID,
                    aiService: aiService,
                    historyStore: historyStore,
                    settingsStore: settingsStore
                )
                editorVMs[doc.id] = vm
            }
            selectedID = state.selectedID ?? documents.first?.id
        } else {
            newTab()
        }
    }
}
