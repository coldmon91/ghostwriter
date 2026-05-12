import Foundation
import Combine
import AppKit

enum AIStatus: Equatable {
    case idle
    case requesting
    case error(String)
}

/// Per-tab editor state. Owns: text, ghost text streaming, debounce, history saving.
@MainActor
final class EditorViewModel: ObservableObject {
    @Published var content: String
    @Published var ghostText: String = ""
    @Published var aiStatus: AIStatus = .idle

    /// Cursor position (in UTF-16 / NSString units, matching NSTextView selectedRange).
    @Published var cursorLocation: Int = 0

    /// Active when a snippet was just inserted and placeholders need to be filled in.
    @Published private(set) var inPlaceholderMode: Bool = false

    /// Imperative requests to update the editor's NSTextView selection.
    let selectionRequests = PassthroughSubject<NSRange, Never>()

    let id: UUID
    private(set) var historyEntryID: UUID?

    private let aiService: AIService
    private let historyStore: HistoryStore
    private let settingsStore: SettingsStore

    private var aiTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var historyDebounceTask: Task<Void, Never>?

    init(
        id: UUID = UUID(),
        initialContent: String = "",
        historyEntryID: UUID? = nil,
        aiService: AIService,
        historyStore: HistoryStore,
        settingsStore: SettingsStore = .shared
    ) {
        self.id = id
        self.content = initialContent
        self.historyEntryID = historyEntryID
        self.aiService = aiService
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.cursorLocation = (initialContent as NSString).length
    }

    // MARK: - Text changes

    /// Called from EditorView whenever text content changes via user input.
    func handleTextChange(newContent: String, cursorLocation: Int) {
        let didChange = newContent != content
        content = newContent
        self.cursorLocation = cursorLocation

        // Auto-exit placeholder mode if all placeholders are gone.
        if inPlaceholderMode && !hasAnyPlaceholder() {
            inPlaceholderMode = false
        }

        // Cancel any in-flight ghost on user input (only if change happened)
        if didChange {
            cancelGhost()
            scheduleGhostRequest()
            scheduleHistorySave()
        }
    }

    /// Called when only cursor moved.
    func handleCursorChange(_ location: Int) {
        if location != cursorLocation {
            cursorLocation = location
            cancelGhost()
        }
    }

    // MARK: - Ghost text orchestration

    private func scheduleGhostRequest() {
        let settings = settingsStore.settings
        guard settings.ghostTextEnabled, !settings.activeAPIKey.isEmpty else { return }
        // Suppress ghost suggestions while filling in snippet placeholders.
        if inPlaceholderMode { return }

        debounceTask?.cancel()
        let delayMs = max(50, settings.debounceMs)
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            if Task.isCancelled { return }
            await self?.fireGhostRequest()
        }
    }

    private func fireGhostRequest() async {
        let settings = settingsStore.settings
        let nsContent = content as NSString
        let cursor = min(max(0, cursorLocation), nsContent.length)
        let preCursor = nsContent.substring(to: cursor)

        guard !preCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Take last N characters as context, aligned to a sentence/paragraph boundary.
        let maxChars = settings.maxContextChars
        let raw: String
        if preCursor.count > maxChars {
            let start = preCursor.index(preCursor.endIndex, offsetBy: -maxChars)
            raw = String(preCursor[start...])
        } else {
            raw = preCursor
        }
        let context = trimToSentenceBoundary(raw)

        aiTask?.cancel()
        aiStatus = .requesting

        let task = Task { [weak self, aiService] in
            guard let self else { return }
            await MainActor.run { self.ghostText = "" }
            do {
                try await aiService.streamCompletion(prompt: context, settings: settings) { delta in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if Task.isCancelled { return }
                        self.ghostText += delta
                    }
                }
                await MainActor.run { self.aiStatus = .idle }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.ghostText = ""
                    self.aiStatus = .error(error.localizedDescription)
                }
            }
        }
        aiTask = task
    }

    /// Confirm ghost text → insert into content, clear ghost.
    /// Returns the new cursor location (UTF-16 units) after insertion.
    @discardableResult
    func acceptGhost() -> Int? {
        guard !ghostText.isEmpty else { return nil }
        let nsContent = content as NSString
        let cursor = min(max(0, cursorLocation), nsContent.length)
        let pre = nsContent.substring(to: cursor)
        let post = nsContent.substring(from: cursor)
        let insert = ghostText
        let newContent = pre + insert + post
        let newCursor = (pre as NSString).length + (insert as NSString).length

        content = newContent
        cursorLocation = newCursor
        ghostText = ""
        cancelGhostTaskOnly()
        scheduleHistorySave()
        return newCursor
    }

    /// ghost text에서 첫 단어(뒤따르는 공백 포함)만 content에 삽입한다.
    /// 남은 ghost는 유지. 수락할 단어가 없으면 nil 반환.
    @discardableResult
    func acceptGhostWord() -> Int? {
        guard !ghostText.isEmpty else { return nil }
        let head = firstWordSegment(of: ghostText)
        guard !head.isEmpty else { return nil }
        let nsContent = content as NSString
        let cursor = min(max(0, cursorLocation), nsContent.length)
        let pre = nsContent.substring(to: cursor)
        let post = nsContent.substring(from: cursor)
        content = pre + head + post
        let newCursor = (pre as NSString).length + (head as NSString).length
        cursorLocation = newCursor
        ghostText = String(ghostText.dropFirst(head.count))
        scheduleHistorySave()
        return newCursor
    }

    /// ghost 문자열에서 "선행 공백 + 단어 + 뒤따르는 공백 1자"를 한 단위로 반환한다.
    /// 예) " hello world" → " hello ", "hello world" → "hello "
    private func firstWordSegment(of text: String) -> String {
        var idx = text.startIndex
        // 선행 공백/개행을 통과
        while idx < text.endIndex, text[idx].isWhitespace || text[idx].isNewline {
            idx = text.index(after: idx)
        }
        // 단어 본체
        while idx < text.endIndex, !text[idx].isWhitespace, !text[idx].isNewline {
            idx = text.index(after: idx)
        }
        // 뒤따르는 공백/개행 1자
        if idx < text.endIndex {
            idx = text.index(after: idx)
        }
        return String(text[..<idx])
    }

    func rejectGhost() {
        ghostText = ""
        cancelGhostTaskOnly()
    }

    private func cancelGhost() {
        ghostText = ""
        cancelGhostTaskOnly()
    }

    private func cancelGhostTaskOnly() {
        debounceTask?.cancel()
        aiTask?.cancel()
        debounceTask = nil
        aiTask = nil
        if case .requesting = aiStatus { aiStatus = .idle }
    }

    // MARK: - History

    private func scheduleHistorySave() {
        guard settingsStore.settings.autoSaveHistory else { return }
        historyDebounceTask?.cancel()
        historyDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            if Task.isCancelled { return }
            await self?.saveHistoryNow()
        }
    }

    func saveHistoryNow() async {
        let id = historyStore.upsert(id: historyEntryID, content: content)
        historyEntryID = id
    }

    // MARK: - Insert helpers (used by snippets)

    func replaceRange(_ range: NSRange, with text: String) -> Int {
        let nsContent = content as NSString
        let safeRange = NSRange(
            location: max(0, min(range.location, nsContent.length)),
            length: max(0, min(range.length, nsContent.length - range.location))
        )
        let updated = nsContent.replacingCharacters(in: safeRange, with: text)
        content = updated
        let newCursor = safeRange.location + (text as NSString).length
        cursorLocation = newCursor
        cancelGhost()
        scheduleHistorySave()
        return newCursor
    }

    /// Insert a snippet body and, if it contains placeholders, enter placeholder mode and
    /// request a selection of the first placeholder.
    /// Returns the cursor position after insertion (at the end of the inserted text), used
    /// when no placeholder is present.
    @discardableResult
    func insertSnippet(_ snippet: Snippet, at range: NSRange) -> Int {
        let insertLocation = max(0, min(range.location, (content as NSString).length))
        let newCursor = replaceRange(range, with: snippet.body)

        // Look for the first placeholder relative to insertLocation.
        guard let regex = try? NSRegularExpression(pattern: Snippet.placeholderPattern) else {
            return newCursor
        }
        let body = snippet.body as NSString
        if let match = regex.firstMatch(in: snippet.body,
                                        range: NSRange(location: 0, length: body.length)) {
            let placeholderRange = NSRange(location: insertLocation + match.range.location,
                                           length: match.range.length)
            inPlaceholderMode = true
            cursorLocation = placeholderRange.location
            selectionRequests.send(placeholderRange)
        }
        return newCursor
    }

    // MARK: - Placeholder navigation

    func nextPlaceholderRange(after location: Int) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: Snippet.placeholderPattern) else { return nil }
        let nsContent = content as NSString
        let total = nsContent.length
        let clampedLoc = max(0, min(location, total))
        let forward = NSRange(location: clampedLoc, length: total - clampedLoc)
        if let m = regex.firstMatch(in: content, range: forward) { return m.range }
        // wrap around
        if let m = regex.firstMatch(in: content, range: NSRange(location: 0, length: clampedLoc)) {
            return m.range
        }
        return nil
    }

    func previousPlaceholderRange(before location: Int) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: Snippet.placeholderPattern) else { return nil }
        let nsContent = content as NSString
        let total = nsContent.length
        let clampedLoc = max(0, min(location, total))
        let head = regex.matches(in: content, range: NSRange(location: 0, length: clampedLoc))
        if let last = head.last { return last.range }
        let tail = regex.matches(in: content, range: NSRange(location: clampedLoc, length: total - clampedLoc))
        if let last = tail.last { return last.range }
        return nil
    }

    func exitPlaceholderMode() {
        inPlaceholderMode = false
    }

    /// last-N으로 잘린 context 슬라이스의 앞 경계를 가장 가까운 문장/문단 경계로 정렬한다.
    /// 경계를 찾지 못하면 원본을 그대로 반환한다.
    private func trimToSentenceBoundary(_ text: String) -> String {
        // 빈 텍스트거나 짧으면 그대로 반환
        guard text.count > 60 else { return text }

        // 문단 경계(\n\n) 또는 문장 종결([.!?。…] + 공백, 또는 다/요/음 + \n)을
        // 앞 1/3 구간에서 찾는다 (너무 뒤에서 자르면 짧아짐).
        let searchEnd = text.index(text.startIndex, offsetBy: text.count / 3)
        let searchRange = text.startIndex..<searchEnd

        // 우선 문단 경계
        if let range = text.range(of: "\n\n", range: searchRange) {
            let trimmed = String(text[range.upperBound...])
            if !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return trimmed
            }
        }

        // 문장 종결 패턴 (영/한 혼용)
        let sentenceEnd = try? NSRegularExpression(
            pattern: #"[.!?。…]\s+|[다요음]\s*\n"#
        )
        let nsText = text as NSString
        let searchNS = NSRange(location: 0, length: nsText.length / 3)
        if let match = sentenceEnd?.firstMatch(in: text, range: searchNS) {
            let afterMatch = NSMaxRange(match.range)
            if afterMatch < nsText.length {
                return nsText.substring(from: afterMatch)
            }
        }

        return text
    }

    private func hasAnyPlaceholder() -> Bool {
        guard let regex = try? NSRegularExpression(pattern: Snippet.placeholderPattern) else { return false }
        let nsContent = content as NSString
        return regex.firstMatch(in: content, range: NSRange(location: 0, length: nsContent.length)) != nil
    }
}
