import Foundation

/// 컴파일된 키바인딩: (key chord, command, optional when AST).
/// `KeybindingStore`가 default 배열과 user JSON을 합쳐 만든다.
struct Keybinding {
    let chord: KeyChord
    let command: CommandID
    let when: WhenExpression?
}

/// keybindings.json의 원시 항목. 디스크 ↔ 메모리 경계 타입.
struct KeybindingRecord: Codable {
    let key: String
    let command: String
    let when: String?
}
