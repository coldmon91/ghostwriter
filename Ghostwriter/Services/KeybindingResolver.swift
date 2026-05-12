import AppKit

/// 컴파일된 keybinding 리스트에서 (event, ctx)에 맞는 명령을 찾는다.
struct KeybindingResolver {
    let bindings: [Keybinding]

    /// reversed 순회로 "JSON에서 나중에 정의된 게 이김" 규칙을 구현.
    /// `noop`이 매치되면 `nil`을 반환해 super.keyDown 위임을 유도.
    func resolve(event: NSEvent, ctx: WhenContext) -> CommandID? {
        let chord = KeyChord.from(event: event)
        for b in bindings.reversed() where b.chord == chord {
            let whenOK = b.when?.evaluate(in: ctx) ?? true
            if whenOK {
                return b.command == .noop ? nil : b.command
            }
        }
        return nil
    }
}

/// 원시 record 배열을 컴파일된 Keybinding으로 변환. 잘못된 항목은 NSLog 후 무시.
enum KeybindingCompiler {
    static func compile(_ records: [KeybindingRecord], source: String) -> [Keybinding] {
        var out: [Keybinding] = []
        out.reserveCapacity(records.count)
        for (idx, rec) in records.enumerated() {
            do {
                let chord = try KeyChordParser.parse(rec.key)
                guard let cmd = CommandID(rawValue: rec.command) else {
                    NSLog("[\(source)] #\(idx): 알 수 없는 command '%@'", rec.command)
                    continue
                }
                let whenAST = try WhenExpressionParser.parse(rec.when ?? "")
                out.append(Keybinding(chord: chord, command: cmd, when: whenAST))
            } catch {
                NSLog("[\(source)] #\(idx): 파싱 실패 (%@): %@",
                      "\(rec.key) → \(rec.command)", "\(error)")
            }
        }
        return out
    }
}
