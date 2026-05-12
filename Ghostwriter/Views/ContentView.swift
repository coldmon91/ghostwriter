import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var tabsVM: TabsViewModel
    @EnvironmentObject var snippetStore: SnippetStore
    @EnvironmentObject var historyStore: HistoryStore
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var dragStartWidth: CGFloat? = nil
    @State private var showSlashPopup: Bool = false
    @State private var slashQuery: String = ""
    @State private var slashAnchor: NSRect = .zero
    @State private var slashSelectedIndex: Int = 0
    @State private var slashFilteredCount: Int = 0
    @State private var slashSelectAction: () -> Void = {}

    private var showSidebar: Binding<Bool> {
        Binding(
            get: { settingsVM.settings.sidebarVisible },
            set: { newValue in
                settingsVM.settings.sidebarVisible = newValue
                settingsVM.save()
            }
        )
    }

    private func toggleSidebar() {
        withAnimation { showSidebar.wrappedValue.toggle() }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(tabsVM: tabsVM)
                .frame(height: 36)
            Divider()

            HStack(spacing: 0) {
                if showSidebar.wrappedValue {
                    sidebar
                        .frame(width: max(180, min(480, settingsVM.settings.sidebarWidth)))
                    sidebarResizeHandle
                }
                editorArea
            }
            .onReceive(NotificationCenter.default.publisher(for: .ghostwriterToggleSidebar)) { _ in
                toggleSidebar()
            }

            Divider()
            if let vm = tabsVM.selectedEditorVM {
                StatusBarView(editorVM: vm)
                    .frame(height: 22)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("사이드바 토글 (⌘1)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    tabsVM.newTab()
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("t", modifiers: .command)
                .help("새 탭")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            SnippetPanel(store: snippetStore) { snippet in
                insertSnippetIntoCurrentEditor(snippet)
            }
            .frame(maxHeight: .infinity)
            Divider()
            HistoryPanel(
                store: historyStore,
                onOpen: { entry in
                    tabsVM.openInNewTab(historyEntryID: entry.id, content: entry.content)
                },
                onCopy: { entry in
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.content, forType: .string)
                }
            )
            .frame(maxHeight: .infinity)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var sidebarResizeHandle: some View {
        ZStack {
            Divider()
            Color.clear
                .frame(width: 6)
                .contentShape(Rectangle())
        }
        .frame(width: 6)
        .onHover { hovering in
            if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = settingsVM.settings.sidebarWidth
                    }
                    let new = max(180, min(480, (dragStartWidth ?? 240) + value.translation.width))
                    settingsVM.settings.sidebarWidth = new
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    settingsVM.save()
                }
        )
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            if let vm = tabsVM.selectedEditorVM {
                EditorView(
                    viewModel: vm,
                    settingsVM: settingsVM,
                    onSlashTrigger: { rect, query in
                        slashAnchor = rect
                        slashQuery = query
                        slashSelectedIndex = 0
                        showSlashPopup = true
                    },
                    onSlashUpdate: { query in
                        slashQuery = query
                        let count = currentSlashSnippets().count
                        slashSelectedIndex = count == 0 ? 0 : min(slashSelectedIndex, count - 1)
                    },
                    onSlashEnd: {
                        showSlashPopup = false
                        slashQuery = ""
                        slashSelectedIndex = 0
                    },
                    onSlashNavigate: { direction in
                        let count = currentSlashSnippets().count
                        guard count > 0 else { return }
                        slashSelectedIndex = max(0, min(count - 1, slashSelectedIndex + direction))
                    },
                    onSlashSelect: {
                        let snippets = currentSlashSnippets()
                        guard snippets.indices.contains(slashSelectedIndex) else { return }
                        insertSlashSnippet(snippets[slashSelectedIndex])
                    }
                )
                .id(vm.id) // ensure NSViewRepresentable rebuilds per tab
            } else {
                Text("탭이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showSlashPopup {
                SnippetPopup(
                    query: slashQuery,
                    snippets: currentSlashSnippets(),
                    selectedIndex: slashSelectedIndex,
                    onSelect: { snippet in
                        insertSlashSnippet(snippet)
                    },
                    onDismiss: {
                        showSlashPopup = false
                    }
                )
                .padding(.top, 8)
                .padding(.leading, 16)
            }
        }
    }

    private func currentSlashSnippets() -> [Snippet] {
        Array(snippetStore.search(slashQuery).prefix(8))
    }

    private func insertSnippetIntoCurrentEditor(_ snippet: Snippet) {
        guard let vm = tabsVM.selectedEditorVM else { return }
        let cursor = vm.cursorLocation
        _ = vm.insertSnippet(snippet, at: NSRange(location: cursor, length: 0))
        snippetStore.incrementUsage(id: snippet.id)
    }

    private func insertSlashSnippet(_ snippet: Snippet) {
        // Replace from the slash position to current cursor with the snippet body.
        // The Coordinator owns slashStart, but we don't have direct reference here, so we
        // reconstruct by scanning back from cursor for the slash run.
        guard let vm = tabsVM.selectedEditorVM else { return }
        let ns = vm.content as NSString
        let cursor = vm.cursorLocation
        var i = cursor
        var slashLoc: Int? = nil
        while i > 0 {
            let prev = i - 1
            let c = ns.substring(with: NSRange(location: prev, length: 1))
            if c == "/" {
                slashLoc = prev
                break
            }
            if c == " " || c == "\n" || c == "\t" { break }
            i = prev
        }
        let start = slashLoc ?? cursor
        let length = max(0, cursor - start)
        _ = vm.insertSnippet(snippet, at: NSRange(location: start, length: length))
        snippetStore.incrementUsage(id: snippet.id)
        showSlashPopup = false
        slashQuery = ""
        slashSelectedIndex = 0
    }
}
