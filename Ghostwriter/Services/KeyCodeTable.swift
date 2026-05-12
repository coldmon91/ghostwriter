import AppKit

/// 키 이름 ↔ macOS virtual key code 매핑. `Carbon/HIToolbox/Events.h`의 kVK_* 값과 동일.
/// 한국어/유럽 키보드에서도 안정적인 매칭을 위해 keyCode 기반으로 정규화한다.
enum KeyCodeTable {
    /// "tab", "a", "cmd" 같은 사용자 입력을 소문자로 정규화한 후 keyCode를 반환.
    static func keyCode(forName name: String) -> UInt16? {
        return table[name.lowercased()]
    }

    private static let table: [String: UInt16] = [
        // 알파벳
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "o": 0x1F,
        "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
        "n": 0x2D, "m": 0x2E,

        // 숫자 (메인 키보드)
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
        "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

        // punctuation
        "=":  0x18,
        "-":  0x1B,
        "]":  0x1E,
        "[":  0x21,
        "'":  0x27,
        ";":  0x29,
        "\\": 0x2A,
        ",":  0x2B,
        "/":  0x2C,
        ".":  0x2F,
        "`":  0x32,

        // 흰색 키
        "space":     0x31,
        "tab":       0x30,
        "enter":     0x24, "return": 0x24,
        "escape":    0x35, "esc":    0x35,
        "backspace": 0x33, "delete": 0x33,
        "forwarddelete": 0x75,

        // 방향
        "left":  0x7B,
        "right": 0x7C,
        "down":  0x7D,
        "up":    0x7E,

        // navigation
        "home":     0x73,
        "end":      0x77,
        "pageup":   0x74,
        "pagedown": 0x79,

        // function
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F
    ]
}
