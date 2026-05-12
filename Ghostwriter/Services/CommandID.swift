import Foundation

/// 에디터에서 디스패치 가능한 명령 ID.
/// `keybindings.json`의 `"command"` 값과 매칭된다.
enum CommandID: String, Codable {
    case noop

    case editorAcceptGhost     = "editor.acceptGhost"
    case editorAcceptGhostWord = "editor.acceptGhostWord"
    case editorRejectGhost     = "editor.rejectGhost"

    case placeholderNext       = "placeholder.next"
    case placeholderPrevious   = "placeholder.previous"
    case placeholderExit       = "placeholder.exit"

    case slashNavigateUp       = "slash.navigateUp"
    case slashNavigateDown     = "slash.navigateDown"
    case slashSelect           = "slash.select"
    case slashDismiss          = "slash.dismiss"

    case cursorLineStart       = "cursor.lineStart"
    case cursorLineEnd         = "cursor.lineEnd"
    case cursorDocStart        = "cursor.docStart"
    case cursorDocEnd          = "cursor.docEnd"
}
