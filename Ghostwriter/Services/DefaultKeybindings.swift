import Foundation

/// 앱에 컴파일되어 들어가는 기본 키바인딩. user `keybindings.json`은 이 배열 뒤에
/// append되어 동일 (key + when) 매치가 있으면 user 가 이긴다 (reversed 순회).
///
/// 순서 주의: resolver는 reversed로 순회하므로 **placeholder/slash 분기를
/// 아래쪽에 둬야** 같은 키(Tab, Esc 등)에서 placeholder/slash가 ghost보다 우선.
enum DefaultKeybindings {
    static let records: [KeybindingRecord] = [
        // ghost (우선순위 가장 낮음)
        .init(key: "tab",
              command: CommandID.editorAcceptGhost.rawValue,
              when: "ghostVisible && !inPlaceholderMode && !slashPopupVisible"),
        .init(key: "cmd+right",
              command: CommandID.editorAcceptGhostWord.rawValue,
              when: "ghostVisible"),
        .init(key: "escape",
              command: CommandID.editorRejectGhost.rawValue,
              when: "ghostVisible && !slashPopupVisible"),

        // placeholder
        .init(key: "tab",
              command: CommandID.placeholderNext.rawValue,
              when: "inPlaceholderMode"),
        .init(key: "shift+tab",
              command: CommandID.placeholderPrevious.rawValue,
              when: "inPlaceholderMode"),
        .init(key: "enter",
              command: CommandID.placeholderExit.rawValue,
              when: "inPlaceholderMode"),
        .init(key: "escape",
              command: CommandID.placeholderExit.rawValue,
              when: "inPlaceholderMode"),

        // 커서 이동 (VSCode/Windows 관례)
        .init(key: "home",
              command: CommandID.cursorLineStart.rawValue,
              when: nil),
        .init(key: "end",
              command: CommandID.cursorLineEnd.rawValue,
              when: nil),
        .init(key: "cmd+home",
              command: CommandID.cursorDocStart.rawValue,
              when: nil),
        .init(key: "cmd+end",
              command: CommandID.cursorDocEnd.rawValue,
              when: nil),

        // slash 팝업 (가장 우선)
        .init(key: "up",
              command: CommandID.slashNavigateUp.rawValue,
              when: "slashPopupVisible"),
        .init(key: "down",
              command: CommandID.slashNavigateDown.rawValue,
              when: "slashPopupVisible"),
        .init(key: "enter",
              command: CommandID.slashSelect.rawValue,
              when: "slashPopupVisible"),
        .init(key: "escape",
              command: CommandID.slashDismiss.rawValue,
              when: "slashPopupVisible")
    ]
}

