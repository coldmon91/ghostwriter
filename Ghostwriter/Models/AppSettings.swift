import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case anthropic
    case openAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }
}

enum OpenAIReasoningEffort: String, Codable, CaseIterable, Identifiable {
    case unset = ""
    case none
    case minimal
    case low
    case medium
    case high
    case xhigh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unset: return "미설정"
        case .none: return "none"
        case .minimal: return "minimal"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .xhigh: return "xhigh"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = OpenAIReasoningEffort(rawValue: rawValue) ?? .unset
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct AppSettings: Codable, Equatable {
    var provider: AIProvider = .anthropic

    // Anthropic
    var apiKey: String = ""
    var model: String = "claude-sonnet-4-20250514"

    // OpenAI Compatible (OpenAI / Azure / OpenRouter / Ollama / LM Studio …)
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var openAIAPIKey: String = ""
    var openAIModel: String = "gpt-4o-mini"
    var openAIReasoningEffort: OpenAIReasoningEffort = .unset

    var debounceMs: Int = 500
    var maxContextChars: Int = 2000
    var maxTokens: Int = 100
    var temperature: Double = 0.3
    var ghostTextEnabled: Bool = true
    var fontFamily: String = "SF Mono"
    var fontSize: Int = 14
    var showLineNumbers: Bool = false
    var autoSaveHistory: Bool = true
    var historyRetentionDays: Int = 90
    var sidebarVisible: Bool = true
    var sidebarWidth: CGFloat = 240

    // AI 사전 프롬프트 — 모든 ghost 호출 시 system prompt에 추가.
    var customSystemPrompt: String = ""

    // Global hotkey (Carbon key codes / modifier flags). ⌘⇧Space by default.
    var globalHotkeyEnabled: Bool = true
    var globalHotkeyKeyCode: UInt32 = 49        // kVK_Space
    var globalHotkeyModifiers: UInt32 = 0x1100  // cmdKey | shiftKey

    static let `default` = AppSettings()

    /// API 키 (현재 provider 기준).
    var activeAPIKey: String {
        switch provider {
        case .anthropic: return apiKey
        case .openAICompatible: return openAIAPIKey
        }
    }

    /// 모델 ID (현재 provider 기준).
    var activeModel: String {
        switch provider {
        case .anthropic: return model
        case .openAICompatible: return openAIModel
        }
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case provider
        case apiKey, model
        case openAIBaseURL, openAIAPIKey, openAIModel, openAIReasoningEffort
        case debounceMs, maxContextChars, maxTokens, temperature
        case ghostTextEnabled, fontFamily, fontSize, showLineNumbers
        case autoSaveHistory, historyRetentionDays
        case sidebarVisible, sidebarWidth
        case customSystemPrompt
        case globalHotkeyEnabled, globalHotkeyKeyCode, globalHotkeyModifiers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        provider = try c.decodeIfPresent(AIProvider.self, forKey: .provider) ?? d.provider
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? d.apiKey
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
        openAIBaseURL = try c.decodeIfPresent(String.self, forKey: .openAIBaseURL) ?? d.openAIBaseURL
        openAIAPIKey = try c.decodeIfPresent(String.self, forKey: .openAIAPIKey) ?? d.openAIAPIKey
        openAIModel = try c.decodeIfPresent(String.self, forKey: .openAIModel) ?? d.openAIModel
        openAIReasoningEffort = try c.decodeIfPresent(
            OpenAIReasoningEffort.self,
            forKey: .openAIReasoningEffort
        ) ?? d.openAIReasoningEffort
        debounceMs = try c.decodeIfPresent(Int.self, forKey: .debounceMs) ?? d.debounceMs
        maxContextChars = try c.decodeIfPresent(Int.self, forKey: .maxContextChars) ?? d.maxContextChars
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? d.maxTokens
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? d.temperature
        ghostTextEnabled = try c.decodeIfPresent(Bool.self, forKey: .ghostTextEnabled) ?? d.ghostTextEnabled
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? d.fontFamily
        fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? d.fontSize
        showLineNumbers = try c.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? d.showLineNumbers
        autoSaveHistory = try c.decodeIfPresent(Bool.self, forKey: .autoSaveHistory) ?? d.autoSaveHistory
        historyRetentionDays = try c.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? d.historyRetentionDays
        sidebarVisible = try c.decodeIfPresent(Bool.self, forKey: .sidebarVisible) ?? d.sidebarVisible
        sidebarWidth = try c.decodeIfPresent(CGFloat.self, forKey: .sidebarWidth) ?? d.sidebarWidth
        customSystemPrompt = try c.decodeIfPresent(String.self, forKey: .customSystemPrompt) ?? d.customSystemPrompt
        globalHotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .globalHotkeyEnabled) ?? d.globalHotkeyEnabled
        globalHotkeyKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .globalHotkeyKeyCode) ?? d.globalHotkeyKeyCode
        globalHotkeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .globalHotkeyModifiers) ?? d.globalHotkeyModifiers
    }
}
