import AppKit
import Combine

/// default + user keybindings.json을 합쳐 컴파일된 `Keybinding` 배열을 제공한다.
/// user 파일이 없으면 default만 사용. JSON 파싱/항목 파싱 실패는 로그 후 무시.
@MainActor
final class KeybindingStore: ObservableObject {
    @Published private(set) var resolver: KeybindingResolver

    init() {
        self.resolver = KeybindingStore.buildResolver()
    }

    /// 디스크에서 user JSON을 다시 읽어 resolver를 갱신.
    func reload() {
        self.resolver = KeybindingStore.buildResolver()
    }

    /// user keybindings.json 경로. 없으면 빈 배열로 생성한 후 경로 반환.
    @discardableResult
    func ensureUserFile() -> URL {
        let url = StoragePaths.keybindingsURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? JSONStore.save([KeybindingRecord](), to: url)
        }
        return url
    }

    private static func buildResolver() -> KeybindingResolver {
        let defaults = KeybindingCompiler.compile(
            DefaultKeybindings.records,
            source: "default"
        )
        let userRecords = JSONStore.load([KeybindingRecord].self,
                                         from: StoragePaths.keybindingsURL) ?? []
        let user = KeybindingCompiler.compile(userRecords, source: "user")
        return KeybindingResolver(bindings: defaults + user)
    }
}
