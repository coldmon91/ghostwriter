# Ghostwriter — AI-Powered Scratchpad for macOS

## 1. 개요 (Overview)

AI 프롬프트를 자주 작성하는 사용자를 위한 macOS 네이티브 메모장 앱.
타이핑 중 AI가 다음 텍스트를 예측하여 고스트 텍스트로 제안하고,
자주 쓰는 프롬프트 패턴을 스니펫으로 저장·재사용할 수 있다.

### 핵심 가치
- **빠른 프롬프트 작성**: 반복적인 텍스트 입력을 AI 자동완성과 스니펫으로 최소화
- **가벼운 메모장**: 브라우저나 다른 앱을 떠나지 않고 빠르게 텍스트를 작성·복사
- **이력 재사용**: 과거 작성한 프롬프트를 검색하고 다시 활용

---

## 2. 타겟 환경 (Target)

| 항목 | 값 |
|---|---|
| 플랫폼 | macOS 14 (Sonoma) 이상 |
| 언어 | Swift 5.9+ |
| UI 프레임워크 | SwiftUI + AppKit (NSTextView) |
| 아키텍처 | MVVM |
| 배포 | 로컬 빌드 (개인 사용), 추후 공증(Notarization) 고려 |

---

## 3. 기능 명세 (Features)

### 3.1 AI 고스트 텍스트 (Ghost Text)

GitHub Copilot 스타일의 인라인 자동완성.

**동작 흐름:**
1. 사용자가 에디터에 텍스트를 입력한다.
2. 타이핑이 멈추면 debounce 타이머(기본 500ms)가 시작된다.
3. 타이머 완료 시, 커서 앞의 텍스트(최대 2,000자)를 컨텍스트로 Anthropic API에 전송한다.
4. 스트리밍 응답(SSE)을 받으며, 커서 위치 뒤에 반투명 고스트 텍스트로 표시한다.
5. 사용자가 **Tab** 키를 누르면 고스트 텍스트가 실제 텍스트로 확정된다.
6. **Esc** 키를 누르면 고스트 텍스트가 사라진다.
7. 사용자가 다른 키를 입력하면 기존 고스트 텍스트가 취소되고 새 debounce가 시작된다.

**AI 호출 파라미터:**

| 파라미터 | 기본값 | 설명 |
|---|---|---|
| model | `claude-sonnet-4-20250514` | 설정에서 변경 가능 |
| max_tokens | `100` | 고스트 텍스트는 짧게 |
| system prompt | 아래 참조 | 이어쓰기 전용 프롬프트 |
| temperature | `0.3` | 결정적이되 약간의 다양성 |

**시스템 프롬프트:**
```
You are a text completion assistant. Given the user's text, output ONLY the natural
continuation. Do not repeat the existing text. Do not add explanations, greetings,
or formatting. Just the next words/sentences that would naturally follow.
```

**에지 케이스:**
- 커서가 텍스트 중간에 있을 때: 커서 앞 텍스트만 컨텍스트로 사용
- 빈 에디터: AI 호출하지 않음
- API 오류/타임아웃: 조용히 실패 (고스트 텍스트 없음), 상태바에 아이콘 표시
- 연속 빠른 입력: 이전 API 요청 취소 후 새 요청

---

### 3.2 스니펫 / 템플릿 시스템 (Snippets)

자주 사용하는 프롬프트 패턴을 저장하고 빠르게 삽입.

**기능:**
- 스니펫 CRUD (생성, 조회, 수정, 삭제)
- 에디터에서 `/` 입력 시 스니펫 목록 팝업 표시
- 예: `/code-review`, `/system-prompt`, `/translate`
- 퍼지 검색으로 필터링
- 스니펫 본문에 `{{placeholder}}` 변수 지원
  - 삽입 시 첫 번째 placeholder에 커서 위치
  - **Tab**으로 다음 placeholder로 이동
- 카테고리/태그 분류

**스니펫 데이터 모델:**
```
Snippet {
    id: UUID
    name: String           // 슬래시 커맨드명 (e.g., "code-review")
    title: String          // 표시명 (e.g., "코드 리뷰 요청")
    body: String           // 본문 (placeholder 포함)
    category: String?      // 분류 태그
    createdAt: Date
    updatedAt: Date
    usageCount: Int        // 사용 빈도 (정렬용)
}
```

**예시 스니펫:**
```
이름: /code-review
본문:
다음 코드를 리뷰해줘.
언어: {{language}}
중점 사항: {{focus}}

\```
{{code}}
\```
```

---

### 3.3 이력 관리 (History)

작성한 모든 텍스트를 자동 저장하고 검색·재사용.

**기능:**
- 에디터 내용이 변경될 때마다 자동 저장 (debounce 2초)
- 이력 목록을 사이드 패널에 표시 (최신순)
- 전문 검색 (SQLite FTS5)
- 이력 항목 클릭 → 새 탭에 로드
- 이력에서 바로 클립보드 복사
- 이력 삭제 (개별 / 전체)

**이력 데이터 모델:**
```
HistoryEntry {
    id: UUID
    content: String        // 전체 텍스트
    preview: String        // 첫 100자 (목록 표시용)
    createdAt: Date
    updatedAt: Date
    characterCount: Int
    isFavorite: Bool       // 즐겨찾기 고정
}
```

---

### 3.4 멀티 탭 에디팅 (Multi-Tab)

여러 프롬프트를 동시에 작업.

**기능:**
- 탭 추가 / 닫기 / 전환
- 각 탭은 독립된 undo/redo 스택
- 각 탭은 독립된 AI 고스트 텍스트 세션
- 탭 제목은 내용의 첫 줄에서 자동 생성
- **⌘+T** 새 탭, **⌘+W** 탭 닫기, **⌘+Shift+[/]** 탭 전환
- 앱 종료 시 열린 탭 상태 복원

---

### 3.5 빠른 동작 (Quick Actions)

**키보드 단축키:**

| 단축키 | 동작 |
|---|---|
| ⌘+C (선택 없을 때) | 에디터 전체 내용 복사 |
| ⌘+Shift+C | 전체 내용 복사 후 에디터 클리어 |
| ⌘+T | 새 탭 |
| ⌘+W | 현재 탭 닫기 |
| ⌘+Shift+[ / ] | 이전/다음 탭 전환 |
| ⌘+, | 설정 열기 |
| ⌘+F | 이력 검색 포커스 |
| ⌘+Shift+Space | 글로벌 단축키 — 앱 창 토글 (숨기기/보이기) |

---

## 4. UI 레이아웃 (Layout)

```
┌──────────────────────────────────────────────────────┐
│  ⌘ Ghostwriter                                    _ □ ✕  │
├──────────────────────────────────────────────────────┤
│ [Tab 1] [Tab 2] [Tab 3]                       [+]   │
├────────────────────┬─────────────────────────────────┤
│                    │                                 │
│   사이드 패널       │         에디터 영역              │
│                    │                                 │
│  ┌──────────────┐  │   사용자가 입력한 텍스트           │
│  │ 📋 스니펫     │  │   여기에 고스트 텍스트가 표시됨     │
│  │              │  │                                 │
│  │ /code-review │  │                                 │
│  │ /system      │  │                                 │
│  │ /translate   │  │                                 │
│  ├──────────────┤  │                                 │
│  │ 🕒 이력      │  │                                 │
│  │              │  │                                 │
│  │ 2025-04-29.. │  │                                 │
│  │ 2025-04-28.. │  │                                 │
│  │ 2025-04-27.. │  │                                 │
│  └──────────────┘  │                                 │
│                    │                                 │
├────────────────────┴─────────────────────────────────┤
│  상태바: ● AI 연결됨  │  1,234자  │  UTF-8            │
└──────────────────────────────────────────────────────┘
```

**사이드 패널:**
- 토글 가능 (⌘+1로 숨기기/보이기)
- 상단: 스니펫 섹션 (접기/펼치기)
- 하단: 이력 섹션 (접기/펼치기)
- 검색바 포함

**에디터 영역:**
- NSTextView 기반
- 모노스페이스 폰트 옵션
- 줄 번호 표시 (토글)
- 고스트 텍스트: 동일 폰트, opacity 40%, 커서 위치 바로 뒤에 렌더링

**상태바:**
- AI 연결 상태 (연결됨/호출 중/오류)
- 글자 수
- 인코딩

---

## 5. 아키텍처 (Architecture)

### 5.1 프로젝트 구조

```
Ghostwriter/
├── AIMemoApp.swift                 # 앱 진입점, 메뉴바, 글로벌 단축키
├── Models/
│   ├── Document.swift              # 에디터 문서 모델
│   ├── Snippet.swift               # 스니펫 데이터 모델
│   └── HistoryEntry.swift          # 이력 데이터 모델
├── ViewModels/
│   ├── EditorViewModel.swift       # 에디터 상태 관리, AI 요청 조율
│   ├── SnippetViewModel.swift      # 스니펫 CRUD
│   ├── HistoryViewModel.swift      # 이력 검색/관리
│   └── SettingsViewModel.swift     # 설정 관리
├── Views/
│   ├── MainWindow.swift            # 메인 윈도우 (탭바 + 사이드패널 + 에디터)
│   ├── EditorView.swift            # NSTextView 래퍼 (NSViewRepresentable)
│   ├── GhostTextManager.swift      # 고스트 텍스트 렌더링 로직
│   ├── SnippetPanel.swift          # 스니펫 목록/편집 SwiftUI 뷰
│   ├── SnippetPopup.swift          # 슬래시 커맨드 팝업
│   ├── HistoryPanel.swift          # 이력 목록 SwiftUI 뷰
│   ├── TabBarView.swift            # 탭 바 뷰
│   └── SettingsView.swift          # 설정 화면
├── Services/
│   ├── AIService.swift             # Anthropic API 클라이언트 (SSE 스트리밍)
│   ├── SnippetStore.swift          # 스니펫 영속성 (JSON 파일)
│   ├── HistoryStore.swift          # 이력 영속성 (SQLite + FTS5)
│   └── HotkeyManager.swift        # 글로벌 단축키 등록
├── Extensions/
│   ├── String+Extensions.swift     # 문자열 유틸리티
│   └── NSTextView+GhostText.swift  # 고스트 텍스트 NSTextView 확장
└── Resources/
    └── DefaultSnippets.json        # 기본 제공 스니펫
```

### 5.2 의존성 (Dependencies)

| 라이브러리 | 용도 | 비고 |
|---|---|---|
| GRDB.swift | SQLite + FTS5 | 이력 저장 및 전문 검색 |
| (없음) | HTTP/SSE | URLSession 직접 구현 (외부 의존성 최소화) |

### 5.3 데이터 흐름

```
[에디터 입력]
    │
    ▼
[EditorViewModel] ──debounce 500ms──▶ [AIService] ──SSE──▶ [GhostTextManager]
    │                                                              │
    │                                                              ▼
    │                                                    [NSTextView에 고스트 렌더링]
    │
    ├──debounce 2s──▶ [HistoryStore] ──SQLite──▶ 💾
    │
    └──"/" 감지──▶ [SnippetPopup] ──선택──▶ [에디터에 삽입]
```

---

## 6. 설정 항목 (Settings)

| 항목 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| API Key | String | (비어있음) | Anthropic API 키 |
| Model | String | `claude-sonnet-4-20250514` | 사용할 모델 |
| Debounce (ms) | Int | `500` | AI 호출 대기 시간 |
| Max Context Chars | Int | `2000` | API에 보낼 최대 컨텍스트 길이 |
| Max Tokens | Int | `100` | 고스트 텍스트 최대 토큰 |
| Temperature | Double | `0.3` | 생성 다양성 |
| Ghost Text Enabled | Bool | `true` | AI 자동완성 활성화 |
| Font Family | String | `SF Mono` | 에디터 폰트 |
| Font Size | Int | `14` | 에디터 폰트 크기 |
| Show Line Numbers | Bool | `false` | 줄 번호 표시 |
| Global Hotkey | String | `⌘+Shift+Space` | 앱 호출 단축키 |
| Auto-save History | Bool | `true` | 자동 이력 저장 |
| History Retention | Int | `90` | 이력 보관 기간 (일) |

---

## 7. 저장 경로 (Storage)

```
~/Library/Application Support/Ghostwriter/
├── settings.json          # 앱 설정
├── snippets.json          # 스니펫 데이터
├── history.sqlite         # 이력 DB (FTS5 포함)
└── tabs-state.json        # 앱 종료 시 탭 상태 백업
```

---

## 8. 향후 고려사항 (Future)

아래는 초기 버전에 포함하지 않으나, 추후 확장 가능한 기능:

- **프롬프트 변수 시스템**: 스니펫보다 고급 — 조건부 블록, 반복 블록
- **클라우드 동기화**: iCloud를 통한 스니펫/이력 동기화
- **프롬프트 라이브러리 공유**: 스니펫을 JSON으로 내보내기/가져오기
- **다중 AI 제공자**: OpenAI, Gemini 등 다른 API 지원
- **Markdown 미리보기**: 에디터 분할 뷰로 렌더링 결과 표시
- **플러그인 시스템**: 사용자 정의 텍스트 변환 (예: 번역, 요약)