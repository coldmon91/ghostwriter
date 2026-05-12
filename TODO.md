# Ghostwriter — TODO

MVP 이후 진행해야 할 작업 목록. 우선순위는 카테고리 순.

---

## 1. PLAN.md 명세 중 미완성

### 1.1 스니펫 — Placeholder 인터랙션 (PLAN §3.2)
- [x] 스니펫 삽입 시 첫 번째 `{{placeholder}}`에 커서 자동 이동
- [x] **Tab** 키로 다음 placeholder로 이동, **Shift+Tab**으로 이전
- [x] 마지막 placeholder 이후 **Enter** 또는 **Esc**로 placeholder 모드 종료
- [x] placeholder 시각적 강조 (배경색/언더라인) — `Snippet.placeholderRanges()`는 이미 모델에 구현됨

### 1.2 슬래시 팝업 — 키보드 네비게이션
- [x] **↑/↓** 화살표로 항목 이동
- [x] **Enter**로 선택, **Esc**로 닫기 (Esc 닫기는 부분 구현됨)
- [x] 현재는 마우스 클릭만 동작

### 1.3 이력 — 전문 검색 (PLAN §3.3)
- [x] GRDB.swift + SQLite FTS5 도입
- [x] `HistoryStore`를 JSON 기반에서 SQLite 기반으로 마이그레이션
- [x] 기존 `history.json` → `history.sqlite` 일회성 변환 로직
- [x] 마이그레이션 후 JSON 백업/롤백 처리

### 1.4 글로벌 단축키 (PLAN §3.5)
- [x] `Services/HotkeyManager.swift` 작성 (Carbon `RegisterEventHotKey` 또는 `MASShortcut`)
- [x] **⌘+Shift+Space** 앱 창 토글 (활성화/숨김)
- [ ] 설정에서 단축키 변경 가능 (캡처 UI)  <!-- 별도 캡처 UI는 후속 — 현재는 기본 ⌘⇧Space 고정/설정 enable 토글만 -->



### 1.5 단축키 보강 (PLAN §3.5)
- [x] **⌘+C** (선택 없을 때) → 에디터 전체 내용 복사
- [x] **⌘+F** → 이력 검색 입력 포커스
- [x] **⌘+1** → 사이드 패널 토글

### 1.6 사이드 패널 토글 단축키
- [x] 현재 toolbar 버튼만 있음 — `⌘+1` 키바인딩 추가
- [x] 사이드바 접힘 상태 영속화 (`UserDefaults` 또는 `AppSettings`)

### 1.7 줄 번호 표시
- [x] 설정 토글(`showLineNumbers`)은 있으나 NSTextView 적용 미구현
- [x] `NSRulerView` 서브클래스 또는 좌측 거터 직접 그리기

---

## 2. 품질 / 안정성

### 2.1 보안 — API 키 보호
- [ ] API 키 저장 위치를 평문 JSON → **Keychain**으로 이전
- [ ] `Security` 프레임워크 또는 `KeychainAccess` 같은 래퍼 검토
- [ ] `settings.json`에서 `apiKey` 필드 제거

### 2.2 테스트
- [ ] `AIServiceTests` — `URLProtocol` mock으로 SSE 파싱 검증
- [ ] `SnippetStoreTests` — CRUD, 검색, 사용 빈도 정렬
- [ ] `HistoryStoreTests` — upsert 동작, 즐겨찾기 정렬, 보존 기간 정리
- [ ] `EditorViewModelTests` — debounce, 고스트 수락/거부, replaceRange 경계 케이스
- [ ] `Snippet.placeholderRanges()` — 정규식 매칭 단위 테스트

### 2.3 에러 처리 / 사용자 피드백
- [ ] AI 호출 실패 시 status bar 점만 깜빡 — 클릭 시 에러 상세 토스트/팝오버
- [ ] API 키 미설정 상태에서 첫 입력 시 안내 배너 표시
- [ ] 네트워크 오프라인 감지 (NWPathMonitor) → 고스트 호출 스킵

### 2.4 코드 정리
- [ ] `AIMemoApp.init()`에서 `historyStore`를 두 번 만드는 묘한 패턴 정리
- [ ] `ContentView.insertSlashSnippet`의 슬래시 위치 재스캔 로직 → Coordinator 호출로 통합
- [ ] `EditorView.updateNSView`의 `applyExternalUpdates` no-op 제거
- [ ] `EditorViewModel`과 Coordinator 간 책임 경계 재검토 (텍스트 동기화 이중 경로)

### 2.5 동시성 / 취소
- [ ] `AIService.streamCompletion`의 `Task.checkCancellation` 호출 위치 검증
- [ ] 빠른 연속 입력 시 이전 SSE 연결이 즉시 끊기는지 부하 테스트

### 2.6 macOS 시스템 통합
- [ ] 앱 아이콘 (`.icns`) 추가 — `Resources/Assets.xcassets/AppIcon.appiconset`
- [ ] 코드 사이닝 (Apple Developer 계정 연동) → Hardened Runtime 활성화
- [ ] 공증 (Notarization) 워크플로 — 배포 시
- [ ] Sparkle 등 자동 업데이트 (선택)

---

## 3. UX 개선

### 3.1 에디터
- [ ] 다크모드 색상 검증 — 고스트 텍스트 가독성 (현재 `secondaryLabelColor` × 0.5)
- [ ] 마크다운 신택스 하이라이팅 (선택)
- [ ] 스크롤 위치 / 선택 영역 탭 전환 시 복원
- [x] 사전 프롬프트 입력 지원 — `{{prePrompt}}` placeholder로 시스템 프롬프트 삽입
- [x] **Ghost write 문맥 연속성 강화** — AI가 추천하는 다음 문장이 기존 적혀있는 문맥을 자연스럽게 이어가도록 개선 (system prompt 튜닝, 직전 문장/문단 경계 인식, 어투·시제 일관성 유지)
- [x] 추천 입력을 Ctrl+RightArrow 또는 Cmd+RightArrow로 한 단어씩 수락
- [ ] 문장 중간에 입력중인 경우, 고스트가 현재 커서 위치를 인식하여 해당 위치에서 텍스트를 이어서 생성하도록 개선 (예: "The cat is on the |mat."에서 "|" 위치에 커서를 두고 고스트 호출 시 "mat." 이후 텍스트가 생성되도록)
- [x] "스니펫"과 "이력" 이 표시되고 있는 메뉴바의 크기를 마우스 드래그로 조절 가능하도록 개선 (현재는 고정)

### 3.2 탭바
- [ ] 탭 드래그로 순서 변경
- [ ] 탭 우클릭 메뉴 (닫기, 다른 탭 모두 닫기, 복제)
- [ ] 탭 너무 많을 때 ScrollView 대신 dropdown 메뉴
- [ ] 변경 안 된 빈 탭은 자동 정리

### 3.3 이력
- [ ] 날짜별 그룹핑 헤더 (오늘 / 어제 / 이번 주 / 이전)
- [ ] 검색 결과 하이라이트
- [ ] 이력 → 클립보드 복사 후 토스트 알림

### 3.4 설정 화면
- [ ] 현재는 "저장" 버튼 — 변경 즉시 저장으로 변경 (`onChange` debounce)
- [ ] API 키 검증 버튼 — 짧은 테스트 호출로 키 유효성 확인
- [ ] 모델 선택을 드롭다운으로 (사용 가능 모델 목록)

### 3.5 첫 실행 가이드
- [ ] 빈 상태에서 안내 화면 ("API 키를 설정하세요" + 단축키 치트시트)
- [ ] 기본 스니펫에 한국어 환영 항목 추가

---

## 4. 향후 확장 (PLAN §8)

- [ ] **프롬프트 변수 시스템 고도화** — 조건부 블록 (`{{#if}}`), 반복 블록 (`{{#each}}`)
- [ ] **클라우드 동기화** — iCloud Drive 또는 CloudKit으로 스니펫 / 이력 동기화
- [ ] **프롬프트 라이브러리 공유** — 스니펫 JSON 내보내기 / 가져오기 + URL 스킴
- [ ] **다중 AI 제공자** — `AIService` 프로토콜화, OpenAI / Gemini / 로컬 LLM 추가
- [ ] **Markdown 미리보기** — 에디터 분할 뷰, 라이브 렌더링
- [ ] **플러그인 시스템** — 사용자 정의 텍스트 변환 (번역, 요약, 포맷팅)
- [ ] **컨텍스트 인지 자동완성** — 직전 에디터 내용 이외에 스니펫 / 이력에서 RAG로 컨텍스트 보강
- [ ] **단축어(snippet alias)** — `;today`, `;email-sig` 같은 trigger 패턴
- [x] **VSCode 스타일 단축키 매핑 지원** — `keymapping.json` (또는 `keybindings.json`)로 사용자 정의 키바인딩 로드, 명령 ID 기반 매핑 테이블, when-context 조건(`editorFocus`, `slashPopupVisible` 등) 지원 — 에디터 계층 한정 (메뉴/글로벌 핫키는 범위 외)
- [ ] 사전 프롬프트가 입력되면 system prompt 는 비활성화 
- [ ] 사전 프롬프트를 사용자가 여러개 준비해 두고, 필요시 적절한 프롬프트를 선택해 적용할 수 있도록 한다.
- [ ] 글씨 간격은 항상 일정하게 유지되도록 한다. 

---

## 5. 문서화 / 개발자 경험

- [ ] `README.md` 작성 — 빌드 방법, 단축키 표, 스크린샷
- [ ] `CHANGELOG.md` 도입
