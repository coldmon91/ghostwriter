import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings

    private let store: SettingsStore

    init(store: SettingsStore = .shared) {
        self.store = store
        self.settings = store.settings
    }

    func save() {
        store.update { $0 = settings }
    }

    func reset() {
        settings = .default
        save()
    }
}
