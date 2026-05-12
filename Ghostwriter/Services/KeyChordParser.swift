import AppKit

/// "cmd+shift+right" 같은 문자열을 `KeyChord`로 파싱한다.
enum KeyChordParser {
    enum ParseError: Error, CustomStringConvertible {
        case empty
        case unknownToken(String)
        case missingKey
        case duplicateKey(String)

        var description: String {
            switch self {
            case .empty: return "빈 chord 문자열"
            case .unknownToken(let t): return "알 수 없는 토큰: \(t)"
            case .missingKey: return "modifier만 있고 key가 없음"
            case .duplicateKey(let s): return "key 토큰이 두 개 이상: \(s)"
            }
        }
    }

    static func parse(_ raw: String) throws -> KeyChord {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        var modifiers: NSEvent.ModifierFlags = []
        var keyName: String?

        // 토큰 분리: '+'로 split, 단 마지막 토큰이 '+' 자체일 가능성 처리.
        // 예) "cmd++" → ["cmd", "", "+"]. 이번 MVP는 단순 split 사용.
        let tokens = trimmed
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        for (idx, tok) in tokens.enumerated() {
            // 빈 토큰이 마지막에 오면 "+" 키 자체로 취급
            if tok.isEmpty {
                if idx == tokens.count - 1, keyName == nil {
                    keyName = "="     // '+' = shift + '=' → shift 추가
                    modifiers.insert(.shift)
                    continue
                }
                throw ParseError.unknownToken("(empty)")
            }
            if let mod = modifier(forToken: tok) {
                modifiers.insert(mod)
            } else if KeyCodeTable.keyCode(forName: tok) != nil {
                if let existing = keyName {
                    throw ParseError.duplicateKey("\(existing), \(tok)")
                }
                keyName = tok
            } else {
                throw ParseError.unknownToken(tok)
            }
        }

        guard let name = keyName, let code = KeyCodeTable.keyCode(forName: name) else {
            throw ParseError.missingKey
        }
        return KeyChord(keyCode: code, modifiers: modifiers)
    }

    private static func modifier(forToken token: String) -> NSEvent.ModifierFlags? {
        switch token {
        case "cmd", "command", "meta":       return .command
        case "shift":                        return .shift
        case "ctrl", "control":              return .control
        case "alt", "opt", "option":         return .option
        default:                             return nil
        }
    }
}
