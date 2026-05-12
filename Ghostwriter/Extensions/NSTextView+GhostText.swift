import AppKit

/// Custom attribute key marking ghost-rendered text in NSTextStorage.
extension NSAttributedString.Key {
    static let isGhostText = NSAttributedString.Key("ghostwriter.isGhostText")
}

extension NSTextView {
    /// Returns the contiguous range covered by ghost-text attributes (if any).
    func ghostTextRange() -> NSRange? {
        guard let storage = textStorage else { return nil }
        let full = NSRange(location: 0, length: storage.length)
        var found: NSRange?
        storage.enumerateAttribute(.isGhostText, in: full, options: []) { value, range, stop in
            if value as? Bool == true {
                found = range
                stop.pointee = true
            }
        }
        return found
    }

    /// Removes any ghost-text run from the storage. Returns the removed range's location, or nil.
    @discardableResult
    func removeGhostText() -> Int? {
        guard let storage = textStorage, let range = ghostTextRange() else { return nil }
        storage.beginEditing()
        storage.deleteCharacters(in: range)
        storage.endEditing()
        return range.location
    }

    /// Inserts ghost text at the given location with the gray styling. Cursor stays at `location`.
    func insertGhostText(_ text: String, at location: Int, font: NSFont) {
        guard !text.isEmpty, let storage = textStorage else { return }
        let safeLoc = max(0, min(location, storage.length))
        let attrs: [NSAttributedString.Key: Any] = [
            .isGhostText: true,
            .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.5),
            .font: font
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        storage.beginEditing()
        storage.insert(attributed, at: safeLoc)
        storage.endEditing()
        setSelectedRange(NSRange(location: safeLoc, length: 0))
    }

    /// ghost run 앞 prefixLength(UTF-16 단위)만 일반 텍스트로 confirm하고, 나머지는 ghost 속성 유지.
    /// ghost가 없거나 prefixLength ≤ 0이면 아무 것도 하지 않는다.
    func confirmGhostHead(prefixLength: Int) {
        guard prefixLength > 0,
              let storage = textStorage,
              let ghostRange = ghostTextRange(),
              ghostRange.length > 0
        else { return }

        let safeLen = min(prefixLength, ghostRange.length)
        let confirmRange = NSRange(location: ghostRange.location, length: safeLen)
        let font = storage.attribute(.font, at: ghostRange.location, effectiveRange: nil)
            ?? NSFont.systemFont(ofSize: 14)
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]
        storage.beginEditing()
        storage.removeAttribute(.isGhostText, range: confirmRange)
        storage.setAttributes(normalAttrs, range: confirmRange)
        storage.endEditing()
    }

    /// Confirms ghost: clears ghost attribute, leaving the text as normal. Returns range that was confirmed.
    @discardableResult
    func confirmGhostText() -> NSRange? {
        guard let storage = textStorage, let range = ghostTextRange() else { return nil }
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: storage.attribute(.font, at: range.location, effectiveRange: nil) ?? NSFont.systemFont(ofSize: 14)
        ]
        storage.beginEditing()
        storage.removeAttribute(.isGhostText, range: range)
        storage.setAttributes(normalAttrs, range: range)
        storage.endEditing()
        return range
    }
}
