import SwiftUI
import AppKit

extension Notification.Name {
    static let ghostwriterFocusHistorySearch = Notification.Name("ghostwriter.focusHistorySearch")
    static let ghostwriterToggleSidebar = Notification.Name("ghostwriter.toggleSidebar")
}

@main
struct GhostwriterApp: App {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var snippetStore = SnippetStore()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var tabsVM: TabsViewModel

    private let aiService: AIService

    init() {
        let ai = AIService()
        self.aiService = ai
        let history = HistoryStore()
        // Pre-instantiate stores; we re-bind below in body via env objects.
        // Note: the @StateObject initializers above are invoked lazily;
        // since TabsViewModel needs aiService + historyStore, we wire it here.
        _tabsVM = StateObject(wrappedValue: TabsViewModel(
            aiService: ai,
            historyStore: history
        ))
        // Replace placeholder historyStore so that the tabs/editor share the same instance.
        // (The @StateObject above for historyStore created a separate instance — but TabsVM
        // also took one. We unify by using the same `history` instance for the env object.)
        _historyStore = StateObject(wrappedValue: history)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabsVM)
                .environmentObject(snippetStore)
                .environmentObject(historyStore)
                .environmentObject(settingsVM)
                .onAppear {
                    historyStore.purgeOld(retentionDays: settingsVM.settings.historyRetentionDays)
                    syncGlobalHotkey()
                }
                .onChange(of: settingsVM.settings.globalHotkeyEnabled) { _, _ in
                    syncGlobalHotkey()
                }
                .onChange(of: settingsVM.settings.globalHotkeyKeyCode) { _, _ in
                    syncGlobalHotkey()
                }
                .onChange(of: settingsVM.settings.globalHotkeyModifiers) { _, _ in
                    syncGlobalHotkey()
                }
                .onDisappear {
                    tabsVM.saveStateNow()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 탭") {
                    tabsVM.newTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("탭 닫기") {
                    if let id = tabsVM.selectedID { tabsVM.closeTab(id: id) }
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("이전 탭") {
                    tabsVM.selectPrevious()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("다음 탭") {
                    tabsVM.selectNext()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .pasteboard) {
                Button("전체 복사") {
                    copyAll(clearAfter: false)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("전체 복사 후 비우기") {
                    copyAll(clearAfter: true)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("사이드바 토글") {
                    NotificationCenter.default.post(name: .ghostwriterToggleSidebar, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
            }

            CommandGroup(after: .textEditing) {
                Button("이력 검색") {
                    NotificationCenter.default.post(name: .ghostwriterFocusHistorySearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            SettingsView(viewModel: settingsVM)
        }
    }

    private func copyAll(clearAfter: Bool) {
        guard let vm = tabsVM.selectedEditorVM else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(vm.content, forType: .string)
        if clearAfter {
            _ = vm.replaceRange(NSRange(location: 0, length: (vm.content as NSString).length), with: "")
        }
    }

    private func syncGlobalHotkey() {
        let manager = HotkeyManager.shared
        manager.onTrigger = { Self.toggleAppActivation() }
        let s = settingsVM.settings
        if s.globalHotkeyEnabled {
            manager.register(keyCode: s.globalHotkeyKeyCode, modifiers: s.globalHotkeyModifiers)
        } else {
            manager.unregister()
        }
    }

    /// If app is active and key window is visible, hide the app; otherwise activate and
    /// bring it to front.
    private static func toggleAppActivation() {
        let app = NSApp
        if app?.isActive == true,
           let keyWindow = app?.keyWindow,
           keyWindow.isVisible {
            app?.hide(nil)
        } else {
            app?.unhide(nil)
            app?.activate(ignoringOtherApps: true)
            app?.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
    }
}
