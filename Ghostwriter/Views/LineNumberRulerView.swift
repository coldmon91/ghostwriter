import AppKit

/// Vertical ruler that draws line numbers for an attached NSTextView.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let labelFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textDidChange(_ note: Notification) {
        recomputeThickness()
        needsDisplay = true
    }

    private func recomputeThickness() {
        guard let storage = textView?.textStorage else { return }
        let total = max(1, storage.string.reduce(into: 1) { acc, ch in if ch == "\n" { acc += 1 } })
        let digits = String(total).count
        let attrs: [NSAttributedString.Key: Any] = [.font: labelFont]
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: attrs).width
        let proposed = max(36, ceil(width) + 16)
        if abs(proposed - ruleThickness) > 0.5 {
            ruleThickness = proposed
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let textStorage = textView.textStorage
        else { return }

        // Background fill matches the ruler rect.
        NSColor.windowBackgroundColor.setFill()
        rect.fill()

        let nsString = textStorage.string as NSString
        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange,
                                                            actualGlyphRange: nil)

        // Count newlines preceding the visible range to derive the starting line number.
        var lineNumber = 1
        if visibleCharRange.location > 0 {
            let leading = nsString.substring(with: NSRange(location: 0, length: visibleCharRange.location))
            lineNumber += leading.reduce(into: 0) { acc, c in if c == "\n" { acc += 1 } }
        }

        let inset = textView.textContainerInset
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        var glyphIndex = visibleGlyphRange.location
        let endIndex = NSMaxRange(visibleGlyphRange)

        while glyphIndex < endIndex {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let paragraphRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))

            // Glyph range for this paragraph's first line fragment only.
            var lineFragmentRange = NSRange(location: NSNotFound, length: 0)
            let firstParagraphGlyph = layoutManager.glyphIndexForCharacter(at: paragraphRange.location)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: firstParagraphGlyph,
                effectiveRange: &lineFragmentRange
            )

            // Convert the text-view-local rect into ruler coordinates.
            let yInTextView = lineRect.minY + inset.height
            let yInRuler = yInTextView - visibleRect.minY
            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attrs)
            let drawPoint = NSPoint(
                x: ruleThickness - labelSize.width - 6,
                y: yInRuler + (lineRect.height - labelSize.height) / 2
            )
            label.draw(at: drawPoint, withAttributes: attrs)

            // Advance to glyph after this paragraph.
            let paragraphEnd = NSMaxRange(paragraphRange)
            if paragraphEnd >= nsString.length { break }
            let nextGlyph = layoutManager.glyphIndexForCharacter(at: paragraphEnd)
            if nextGlyph == glyphIndex { break }
            glyphIndex = nextGlyph
            lineNumber += 1
        }
    }
}
