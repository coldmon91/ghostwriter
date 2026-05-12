import AppKit

/// 정규화된 (keyCode, modifiers) 쌍. 키바인딩 매칭의 기본 단위.
struct KeyChord: Hashable {
    let keyCode: UInt16
    /// `.command`, `.shift`, `.control`, `.option` 만 보존.
    let modifiers: NSEvent.ModifierFlags

    static let relevantModifiers: NSEvent.ModifierFlags =
        [.command, .shift, .control, .option]

    /// NSEvent의 키 이벤트로부터 chord를 추출.
    static func from(event: NSEvent) -> KeyChord {
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection(relevantModifiers)
        return KeyChord(keyCode: event.keyCode, modifiers: mods)
    }

    // NSEvent.ModifierFlags가 Hashable이 아니므로 rawValue로 합성한다.
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }

    static func == (lhs: KeyChord, rhs: KeyChord) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}
