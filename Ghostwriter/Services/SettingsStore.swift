import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private(set) var settings: AppSettings

    private init() {
        if let loaded = JSONStore.load(AppSettings.self, from: StoragePaths.settingsURL) {
            self.settings = loaded
        } else {
            self.settings = .default
        }
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }

    func save() {
        do {
            try JSONStore.save(settings, to: StoragePaths.settingsURL)
        } catch {
            NSLog("SettingsStore.save failed: %@", "\(error)")
        }
    }
}
