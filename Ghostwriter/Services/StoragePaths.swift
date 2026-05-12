import Foundation

enum StoragePaths {
    static var appSupportDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Ghostwriter", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var settingsURL: URL { appSupportDirectory.appendingPathComponent("settings.json") }
    static var snippetsURL: URL { appSupportDirectory.appendingPathComponent("snippets.json") }
    static var historyURL: URL  { appSupportDirectory.appendingPathComponent("history.json") }
    static var historyDBURL: URL { appSupportDirectory.appendingPathComponent("history.sqlite") }
    static var historyJSONBackupURL: URL {
        appSupportDirectory.appendingPathComponent("history.json.bak")
    }
    static var tabsStateURL: URL { appSupportDirectory.appendingPathComponent("tabs-state.json") }
    static var keybindingsURL: URL { appSupportDirectory.appendingPathComponent("keybindings.json") }
}
