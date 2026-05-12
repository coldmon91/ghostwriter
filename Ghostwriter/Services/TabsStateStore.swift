import Foundation

enum TabsStateStore {
    static func load() -> PersistedTabState? {
        JSONStore.load(PersistedTabState.self, from: StoragePaths.tabsStateURL)
    }

    static func save(_ state: PersistedTabState) {
        do {
            try JSONStore.save(state, to: StoragePaths.tabsStateURL)
        } catch {
            NSLog("TabsStateStore.save failed: %@", "\(error)")
        }
    }
}
