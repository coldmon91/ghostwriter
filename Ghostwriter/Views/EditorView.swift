import SwiftUI
import AppKit
import Combine

/// SwiftUI wrapper around NSTextView with ghost-text inline rendering.
struct EditorView: NSViewRepresentable {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var settingsVM: SettingsViewModel
    @ObservedObject var keybindingStore: KeybindingStore

    /// Called when user types `/` in a slash-command position.
    var onSlashTrigger: (NSRect, String) -> Void = { _, _ in }
    /// Called whenever cursor moves while a slash query is active so that the host can update filter.
    var onSlashUpdate: (String) -> Void = { _ in }
    /// Called when slash session should end (cursor moved away or whitespace inserted).
    var onSlashEnd: () -> Void = {}
    /// Called on ↑ / ↓ while slash session is active. +1 = down, -1 = up.
    var onSlashNavigate: (Int) -> Void = { _ in }
    /// Called on Enter while slash session is active.
    var onSlashSelect: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel,
                    settingsVM: settingsVM,
                    keybindingStore: keybindingStore,
                    onSlashTrigger: onSlashTrigger,
                    onSlashUpdate: onSlashUpdate,
                    onSlashEnd: onSlashEnd,
                    onSlashNavigate: onSlashNavigate,
                    onSlashSelect: onSlashSelect)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width,
                                                                  height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = EditorTextView(frame: NSRect(origin: .zero, size: contentSize),
                                      textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width

        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = true
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = context.coordinator.currentFont()
        textView.delegate = context.coordinator

        textView.textContainerInset = NSSize(width: 8, height: 12)

        // keybindings.json 기반 인터셉터를 NSTextView에 연결.
        textView.onKeyDownIntercept = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyEvent(event) ?? false
        }

        scrollView.documentView = textView

        // Line number ruler.
        scrollView.hasVerticalRuler = true
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.rulersVisible = settingsVM.settings.showLineNumbers

        // Initial content
        textView.string = viewModel.content
        textView.setSelectedRange(NSRange(location: viewModel.cursorLocation, length: 0))

        context.coordinator.attach(textView: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.applyExternalUpdates(textView: textView)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let viewModel: EditorViewModel
        let settingsVM: SettingsViewModel
        let keybindingStore: KeybindingStore
        let onSlashTrigger: (NSRect, String) -> Void
        let onSlashUpdate: (String) -> Void
        let onSlashEnd: () -> Void
        let onSlashNavigate: (Int) -> Void
        let onSlashSelect: () -> Void

        private weak var textView: NSTextView?
        private var cancellables = Set<AnyCancellable>()
        private var slashStart: Int?    // location of the '/' character (UTF-16)
        private var pendingExternalContent: String?
        private var suppressTextDidChange = false

        init(
            viewModel: EditorViewModel,
            settingsVM: SettingsViewModel,
            keybindingStore: KeybindingStore,
            onSlashTrigger: @escaping (NSRect, String) -> Void,
            onSlashUpdate: @escaping (String) -> Void,
            onSlashEnd: @escaping () -> Void,
            onSlashNavigate: @escaping (Int) -> Void,
            onSlashSelect: @escaping () -> Void
        ) {
            self.viewModel = viewModel
            self.settingsVM = settingsVM
            self.keybindingStore = keybindingStore
            self.onSlashTrigger = onSlashTrigger
            self.onSlashUpdate = onSlashUpdate
            self.onSlashEnd = onSlashEnd
            self.onSlashNavigate = onSlashNavigate
            self.onSlashSelect = onSlashSelect
        }

        func attach(textView: NSTextView) {
            self.textView = textView

            // Reflect ghostText changes from VM into the text view.
            viewModel.$ghostText
                .receive(on: RunLoop.main)
                .sink { [weak self] newGhost in
                    self?.applyGhost(newGhost)
                }
                .store(in: &cancellables)

            // Reflect content changes from VM (e.g. snippet inserts) into the text view.
            viewModel.$content
                .receive(on: RunLoop.main)
                .sink { [weak self] newContent in
                    self?.applyContentIfChanged(newContent)
                }
                .store(in: &cancellables)

            settingsVM.$settings
                .map { ($0.fontFamily, $0.fontSize) }
                .removeDuplicates(by: { $0 == $1 })
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self, let tv = self.textView else { return }
                    tv.font = self.currentFont()
                }
                .store(in: &cancellables)

            settingsVM.$settings
                .map(\.showLineNumbers)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] visible in
                    guard let self, let tv = self.textView, let scroll = tv.enclosingScrollView else { return }
                    scroll.rulersVisible = visible
                    scroll.verticalRulerView?.needsDisplay = true
                }
                .store(in: &cancellables)

            viewModel.selectionRequests
                .receive(on: RunLoop.main)
                .sink { [weak self] range in
                    guard let self, let tv = self.textView else { return }
                    self.suppressTextDidChange = true
                    let len = (tv.string as NSString).length
                    let safe = NSRange(
                        location: min(range.location, len),
                        length: min(range.length, max(0, len - range.location))
                    )
                    tv.setSelectedRange(safe)
                    tv.scrollRangeToVisible(safe)
                    self.suppressTextDidChange = false
                    self.refreshPlaceholderHighlights()
                }
                .store(in: &cancellables)

            viewModel.$inPlaceholderMode
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.refreshPlaceholderHighlights()
                }
                .store(in: &cancellables)
        }

        // MARK: - Placeholder highlighting

        private func refreshPlaceholderHighlights() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.backgroundColor, range: fullRange)

            guard viewModel.inPlaceholderMode,
                  let regex = try? NSRegularExpression(pattern: Snippet.placeholderPattern)
            else { return }

            let highlight = NSColor.systemYellow.withAlphaComponent(0.30)
            let matches = regex.matches(in: storage.string, range: fullRange)
            for m in matches {
                storage.addAttribute(.backgroundColor, value: highlight, range: m.range)
            }
        }

        func currentFont() -> NSFont {
            let size = CGFloat(settingsVM.settings.fontSize)
            return NSFont(name: settingsVM.settings.fontFamily, size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }

        // MARK: - VM → TextView updates

        private func applyContentIfChanged(_ newContent: String) {
            guard let tv = textView else { return }
            // Compute current text with ghost stripped.
            let currentNonGhost = stringWithoutGhost(tv: tv)
            if newContent == currentNonGhost { return }
            suppressTextDidChange = true
            // Preserve cursor as best as we can.
            let prevSel = tv.selectedRange()
            tv.string = newContent
            let newLen = (newContent as NSString).length
            let newCursor = min(viewModel.cursorLocation, newLen)
            tv.setSelectedRange(NSRange(location: newCursor, length: 0))
            suppressTextDidChange = false
            // Ghost is gone after replacing the whole string — make VM consistent.
            if !viewModel.ghostText.isEmpty {
                viewModel.rejectGhost()
            }
            _ = prevSel
        }

        private func applyGhost(_ newGhost: String) {
            guard let tv = textView else { return }
            // Always clear existing ghost first.
            suppressTextDidChange = true
            _ = tv.removeGhostText()
            if !newGhost.isEmpty {
                let cursor = min(viewModel.cursorLocation, (tv.string as NSString).length)
                tv.insertGhostText(newGhost, at: cursor, font: currentFont())
            }
            suppressTextDidChange = false
        }

        private func stringWithoutGhost(tv: NSTextView) -> String {
            guard let storage = tv.textStorage else { return tv.string }
            if let ghost = tv.ghostTextRange() {
                let mutable = NSMutableString(string: storage.string)
                mutable.deleteCharacters(in: ghost)
                return mutable as String
            }
            return storage.string
        }

        // MARK: - TextView events

        func applyExternalUpdates(textView: NSTextView) {
            // No-op for now; SwiftUI binding triggered updateNSView is handled via Combine.
        }

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
            // If ghost text is present, strip before any change so it doesn't interfere.
            if textView.ghostTextRange() != nil {
                _ = textView.removeGhostText()
                if !viewModel.ghostText.isEmpty { viewModel.rejectGhost() }
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView, !suppressTextDidChange else { return }
            // Ignore ghost runs (they shouldn't be present here, but defensive).
            let text = stringWithoutGhost(tv: tv)
            let cursor = tv.selectedRange().location
            viewModel.handleTextChange(newContent: text, cursorLocation: cursor)
            evaluateSlashContext(text: text, cursor: cursor)
            if viewModel.inPlaceholderMode {
                refreshPlaceholderHighlights()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView, !suppressTextDidChange else { return }
            let cursor = tv.selectedRange().location
            viewModel.handleCursorChange(cursor)
            evaluateSlashContext(text: stringWithoutGhost(tv: tv), cursor: cursor)
        }

        /// 모든 에디터 명령 디스패치는 `keybindings.json` 매핑을 거치므로,
        /// `doCommandBy`는 stub. NSTextView 기본 동작(텍스트 입력, 커서 이동 등)이
        /// 그대로 흐르도록 false만 반환한다.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            return false
        }

        // MARK: - Keybinding dispatch

        /// `EditorTextView.keyDown(with:)`에서 호출. 매핑된 명령이 있으면 dispatch 후 true.
        func handleKeyEvent(_ event: NSEvent) -> Bool {
            guard let tv = textView else { return false }
            let ctx = currentWhenContext(textView: tv)
            guard let command = keybindingStore.resolver.resolve(event: event, ctx: ctx) else {
                return false
            }
            dispatch(command)
            return true
        }

        private func currentWhenContext(textView tv: NSTextView) -> WhenContext {
            let ghostVisible = !viewModel.ghostText.isEmpty || (tv.ghostTextRange() != nil)
            return WhenContext(
                editorFocus: tv.window?.firstResponder === tv,
                ghostVisible: ghostVisible,
                inPlaceholderMode: viewModel.inPlaceholderMode,
                slashPopupVisible: slashStart != nil,
                hasSelection: tv.selectedRange().length > 0
            )
        }

        private func dispatch(_ command: CommandID) {
            switch command {
            case .noop:
                break
            case .editorAcceptGhost:
                handleAcceptGhost()
            case .editorAcceptGhostWord:
                handleAcceptGhostWord()
            case .editorRejectGhost:
                handleRejectGhost()
            case .placeholderNext:
                moveToNextPlaceholder(forward: true)
            case .placeholderPrevious:
                moveToNextPlaceholder(forward: false)
            case .placeholderExit:
                viewModel.exitPlaceholderMode()
            case .slashNavigateUp:
                onSlashNavigate(-1)
            case .slashNavigateDown:
                onSlashNavigate(1)
            case .slashSelect:
                onSlashSelect()
            case .slashDismiss:
                onSlashEnd()
                slashStart = nil
            case .cursorLineStart:
                textView?.moveToBeginningOfLine(nil)
            case .cursorLineEnd:
                textView?.moveToEndOfLine(nil)
            case .cursorDocStart:
                textView?.moveToBeginningOfDocument(nil)
            case .cursorDocEnd:
                textView?.moveToEndOfDocument(nil)
            }
        }

        // MARK: - Command handlers

        private func handleAcceptGhost() {
            guard let textView = textView,
                  textView.ghostTextRange() != nil,
                  !viewModel.ghostText.isEmpty
            else { return }
            guard let newCursor = viewModel.acceptGhost() else { return }
            suppressTextDidChange = true
            textView.confirmGhostText()
            textView.setSelectedRange(NSRange(location: newCursor, length: 0))
            suppressTextDidChange = false
            viewModel.handleCursorChange(newCursor)
        }

        private func handleAcceptGhostWord() {
            guard let textView = textView,
                  textView.ghostTextRange() != nil,
                  !viewModel.ghostText.isEmpty
            else { return }
            let ghostBefore = viewModel.ghostText
            guard let newCursor = viewModel.acceptGhostWord() else { return }
            let acceptedLen = (ghostBefore as NSString).length
                - (viewModel.ghostText as NSString).length
            suppressTextDidChange = true
            textView.confirmGhostHead(prefixLength: acceptedLen)
            textView.setSelectedRange(NSRange(location: newCursor, length: 0))
            suppressTextDidChange = false
            viewModel.handleCursorChange(newCursor)
        }

        private func handleRejectGhost() {
            guard let textView = textView else { return }
            if textView.ghostTextRange() != nil {
                _ = textView.removeGhostText()
            }
            viewModel.rejectGhost()
            if slashStart != nil {
                onSlashEnd()
                slashStart = nil
            }
        }

        // MARK: - Slash command detection

        private func evaluateSlashContext(text: String, cursor: Int) {
            let ns = text as NSString
            // Walk back from cursor to find a slash with no whitespace in between.
            var i = cursor
            var slashLoc: Int? = nil
            while i > 0 {
                let prev = i - 1
                let c = ns.substring(with: NSRange(location: prev, length: 1))
                if c == "/" {
                    // Slash must be at start of text or after whitespace/newline.
                    if prev == 0 {
                        slashLoc = prev
                        break
                    }
                    let prevBefore = ns.substring(with: NSRange(location: prev - 1, length: 1))
                    if prevBefore == " " || prevBefore == "\n" || prevBefore == "\t" {
                        slashLoc = prev
                    }
                    break
                }
                if c == " " || c == "\n" || c == "\t" { break }
                i = prev
            }

            guard let loc = slashLoc else {
                if slashStart != nil { onSlashEnd() }
                slashStart = nil
                return
            }

            let queryRange = NSRange(location: loc + 1, length: cursor - loc - 1)
            let query = queryRange.length > 0 ? ns.substring(with: queryRange) : ""

            if slashStart == nil {
                slashStart = loc
                if let tv = textView, let rect = caretRectOnScreen(tv: tv, location: loc) {
                    onSlashTrigger(rect, query)
                }
            } else {
                slashStart = loc
                onSlashUpdate(query)
            }
        }

        private func caretRectOnScreen(tv: NSTextView, location: Int) -> NSRect? {
            guard let lm = tv.layoutManager, let tc = tv.textContainer else { return nil }
            let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: location, length: 1),
                                           actualCharacterRange: nil)
            let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            let inView = rect.offsetBy(dx: tv.textContainerOrigin.x, dy: tv.textContainerOrigin.y)
            let onWindow = tv.convert(inView, to: nil)
            guard let window = tv.window else { return nil }
            return window.convertToScreen(onWindow)
        }

        // External call from the slash popup when an item is chosen.
        func insertSnippet(_ snippet: Snippet) {
            guard let tv = textView else { return }
            // Replace the slash range up to current cursor with the snippet body.
            guard let start = slashStart else { return }
            let cursor = tv.selectedRange().location
            let length = max(0, cursor - start)
            let range = NSRange(location: start, length: length)
            performSnippetInsertion(textView: tv, range: range, snippet: snippet)
            slashStart = nil
            onSlashEnd()
        }

        func insertSnippetFromSidebar(_ snippet: Snippet) {
            guard let tv = textView else { return }
            let cursor = tv.selectedRange().location
            let range = NSRange(location: cursor, length: 0)
            performSnippetInsertion(textView: tv, range: range, snippet: snippet)
        }

        private func performSnippetInsertion(textView: NSTextView, range: NSRange, snippet: Snippet) {
            // Replace text view content directly to avoid double edit, then drive VM to update
            // its content + placeholder mode in sync.
            suppressTextDidChange = true
            textView.replaceCharacters(in: range, with: snippet.body)
            suppressTextDidChange = false
            let newCursor = viewModel.insertSnippet(snippet, at: range)
            if !viewModel.inPlaceholderMode {
                suppressTextDidChange = true
                textView.setSelectedRange(NSRange(location: newCursor, length: 0))
                suppressTextDidChange = false
            }
            // selection for placeholder mode is delivered through selectionRequests publisher.
        }

        private func moveToNextPlaceholder(forward: Bool) {
            guard let tv = textView else { return }
            let selection = tv.selectedRange()
            let target: NSRange?
            if forward {
                target = viewModel.nextPlaceholderRange(after: NSMaxRange(selection))
            } else {
                target = viewModel.previousPlaceholderRange(before: selection.location)
            }
            if let next = target {
                suppressTextDidChange = true
                tv.setSelectedRange(next)
                tv.scrollRangeToVisible(next)
                suppressTextDidChange = false
            } else {
                viewModel.exitPlaceholderMode()
            }
        }
    }
}
