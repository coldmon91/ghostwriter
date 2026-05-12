import AppKit

/// Custom NSTextView subclass that:
/// - copies the entire content when ⌘C is pressed with no selection
/// - hooks line-number ruler invalidation on content changes
final class EditorTextView: NSTextView {
    override func copy(_ sender: Any?) {
        if selectedRange().length == 0 {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
            return
        }
        super.copy(sender)
    }

    /// Force the line-number ruler (if attached) to redraw whenever the text changes.
    override func didChangeText() {
        super.didChangeText()
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }
}
