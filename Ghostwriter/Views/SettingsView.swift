import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var keybindingStore: KeybindingStore

    var body: some View {
        TabView {
            generalTab.tabItem { Label("일반", systemImage: "gear") }
            aiTab.tabItem { Label("AI", systemImage: "sparkles") }
            editorTab.tabItem { Label("에디터", systemImage: "text.alignleft") }
            historyTab.tabItem { Label("이력", systemImage: "clock") }
            keybindingsTab.tabItem { Label("키바인딩", systemImage: "keyboard") }
        }
        .frame(width: 600, height: 520)
        .padding(20)
    }

    private var keybindingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("키바인딩 (keybindings.json)")
                .font(.headline)
            Text("""
            사용자 정의 키매핑은 \
            `~/Library/Application Support/Ghostwriter/keybindings.json` 파일에 \
            저장됩니다. 파일을 편집한 뒤 "다시 불러오기"를 누르세요.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("keybindings.json 열기") {
                    let url = keybindingStore.ensureUserFile()
                    NSWorkspace.shared.open(url)
                }
                Button("다시 불러오기") {
                    keybindingStore.reload()
                }
                Spacer()
            }

            Divider()

            Text("사용 가능한 명령 ID").font(.subheadline).bold()
            Text("""
            - editor.acceptGhost / editor.acceptGhostWord / editor.rejectGhost
            - placeholder.next / placeholder.previous / placeholder.exit
            - slash.navigateUp / slash.navigateDown / slash.select / slash.dismiss
            - cursor.lineStart / cursor.lineEnd / cursor.docStart / cursor.docEnd
            - noop (기본 매핑을 비활성화할 때 사용)
            """)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            Text("when 식별자").font(.subheadline).bold()
            Text("""
            editorFocus, ghostVisible, inPlaceholderMode, \
            slashPopupVisible, hasSelection
            연산자: && || ! ()
            """)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            Text("예시").font(.subheadline).bold()
            Text("""
            [
              { "key": "cmd+j", "command": "editor.acceptGhostWord",
                "when": "ghostVisible" },
              { "key": "tab",   "command": "noop",
                "when": "ghostVisible" }
            ]
            """)
            .font(.caption.monospaced())
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()
        }
        .padding()
    }

    private var generalTab: some View {
        Form {
            Toggle("AI 자동완성 활성화", isOn: $viewModel.settings.ghostTextEnabled)
            Toggle("이력 자동 저장", isOn: $viewModel.settings.autoSaveHistory)
            HStack {
                Text("이력 보관 기간 (일)")
                Spacer()
                TextField("", value: $viewModel.settings.historyRetentionDays, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("저장") { viewModel.save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private var aiTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    labeledRow("Provider") {
                        Picker("", selection: $viewModel.settings.provider) {
                            ForEach(AIProvider.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    switch viewModel.settings.provider {
                    case .anthropic:
                        anthropicFields
                    case .openAICompatible:
                        openAIFields
                    }

                    Divider().padding(.vertical, 4)

                    labeledRow("Debounce (ms)") {
                        TextField("", value: $viewModel.settings.debounceMs, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Spacer()
                    }
                    labeledRow("최대 컨텍스트 (자)") {
                        TextField("", value: $viewModel.settings.maxContextChars, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Spacer()
                    }
                    labeledRow("최대 토큰") {
                        TextField("", value: $viewModel.settings.maxTokens, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Spacer()
                    }
                    labeledRow("Temperature") {
                        Slider(value: $viewModel.settings.temperature, in: 0...1, step: 0.05)
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.2f", viewModel.settings.temperature))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }

                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("사전 프롬프트")
                            .frame(width: 140, alignment: .leading)
                        TextEditor(text: $viewModel.settings.customSystemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80, maxHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        Text("모든 ghost 호출에 함께 전송됩니다. 비워두면 기본 프롬프트만 사용합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("저장") { viewModel.save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 10)
        }
        .padding()
    }

    /// 라벨 폭을 고정해 모든 행을 정렬한다.
    @ViewBuilder
    private func labeledRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(width: 140, alignment: .leading)
            content()
        }
    }

    @ViewBuilder
    private var anthropicFields: some View {
        labeledRow("Anthropic API 키") {
            SecureField("sk-ant-...", text: $viewModel.settings.apiKey)
                .textFieldStyle(.roundedBorder)
        }
        labeledRow("모델") {
            TextField("claude-sonnet-4-20250514", text: $viewModel.settings.model)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var openAIFields: some View {
        labeledRow("Base URL") {
            TextField("https://api.openai.com/v1", text: $viewModel.settings.openAIBaseURL)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
        }
        labeledRow("API 키") {
            SecureField("sk-...", text: $viewModel.settings.openAIAPIKey)
                .textFieldStyle(.roundedBorder)
        }
        labeledRow("모델") {
            TextField("gpt-4o-mini", text: $viewModel.settings.openAIModel)
                .textFieldStyle(.roundedBorder)
        }
        labeledRow("Reasoning Effort") {
            Picker("", selection: $viewModel.settings.openAIReasoningEffort) {
                ForEach(OpenAIReasoningEffort.allCases) { effort in
                    Text(effort.displayName).tag(effort)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180, alignment: .leading)
            Spacer()
        }
    }

    private var editorTab: some View {
        Form {
            labeledRow("폰트") {
                TextField("", text: $viewModel.settings.fontFamily)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Spacer()
            }
            labeledRow("폰트 크기") {
                Stepper(value: $viewModel.settings.fontSize, in: 9...32) {
                    Text("\(viewModel.settings.fontSize)pt")
                }
                .frame(width: 160)
                Spacer()
            }
            labeledRow("줄 번호") {
                Toggle("", isOn: $viewModel.settings.showLineNumbers)
                    .labelsHidden()
                Spacer()
            }
            HStack {
                Spacer()
                Button("저장") { viewModel.save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private var historyTab: some View {
        Form {
            Toggle("이력 자동 저장", isOn: $viewModel.settings.autoSaveHistory)
            HStack {
                Text("보관 기간 (일)")
                Spacer()
                TextField("", value: $viewModel.settings.historyRetentionDays, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("저장") { viewModel.save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
