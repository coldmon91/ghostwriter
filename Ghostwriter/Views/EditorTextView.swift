import AppKit

/// Custom NSTextView subclass that:
/// - copies the entire content when ⌘C is pressed with no selection
/// - hooks line-number ruler invalidation on content changes
/// - delegates key events to a Coordinator-installed interceptor (keybindings.json)
final class EditorTextView: NSTextView {
    /// keyDown 가로채기 콜백. `true`를 반환하면 super 호출 없이 종료한다.
    /// IME(한글 등) 조합 중에는 호출되지 않는다.
    var onKeyDownIntercept: ((NSEvent) -> Bool)?

    override func copy(_ sender: Any?) {
        if selectedRange().length == 0 {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
            return
        }
        super.copy(sender)
    }

    /// 선택 영역이 없을 때 Cmd+X → 현재 줄(개행 포함)을 잘라낸다.
    override func cut(_ sender: Any?) {
        if selectedRange().length == 0 {
            let ns = string as NSString
            let cursor = max(0, min(selectedRange().location, ns.length))
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            if lineRange.length > 0 {
                setSelectedRange(lineRange)
            }
        }
        super.cut(sender)
    }

    /// NSTextView는 선택이 없으면 `cut:`/`copy:`를 자동 비활성화한다.
    /// no-selection 케이스를 우리 오버라이드에서 처리하므로 항상 활성으로 둔다.
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(NSText.cut(_:)):
            return isEditable
        case #selector(NSText.copy(_:)):
            return true
        default:
            return super.validateMenuItem(menuItem)
        }
    }

    /// Force the line-number ruler (if attached) to redraw whenever the text changes.
    override func didChangeText() {
        super.didChangeText()
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        // IME 조합 중에는 인터셉트하지 않는다 — 한글 조합이 깨진다.
        if hasMarkedText() {
            super.keyDown(with: event)
            return
        }
        if onKeyDownIntercept?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
