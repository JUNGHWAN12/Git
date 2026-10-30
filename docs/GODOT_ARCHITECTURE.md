# 🟩 Godot 아키텍처 설계서
### 「커밋 크래프트」 Godot 4 구현 기준 v1.0

> **엔진 확정: Godot 4.7.2 (표준판), GDScript, Compatibility 렌더러.**
> 실행 대상: Windows 학교 PC ([Windows 실행 환경](WINDOWS_ENVIRONMENT.md)).
> Git 동작 규칙은 [Git 시뮬레이터 명세](GIT_SIMULATOR_SPEC.md), 퍼즐은 [MVP 스테이지 명세](STAGE_SPEC_MVP.md)를 그대로 따른다. 엔진이 바뀌어도 이 두 문서는 바뀌지 않는다.

---

## 1. 결정 요약

| 항목 | 결정 | 이유 |
|---|---|---|
| 엔진 버전 | **Godot 4.7.2 stable** 고정 (4.7.x 패치만 올림) | 개발 중 엔진 변경으로 인한 깨짐 방지 |
| 언어 | **GDScript만** (C# 사용 안 함) | 웹 내보내기 호환, .NET 설치 불필요, 배우기 쉬움 |
| 렌더러 | **Compatibility** (OpenGL/WebGL 계열) | 내장 그래픽 저사양 PC·웹 내보내기에 가장 안정적 |
| 화면 기준 | 1366×768, `canvas_items` 늘이기 | 학교 PC 최소 해상도 |
| 배포 ① | **Windows 실행 파일** (pck 내장 단일 exe) | 오프라인·교내 공유 폴더에서 실행, 데스크톱 한글 입력(IME) 사용 (P0에서 확인) |
| 배포 ② | **웹 내보내기** (Edge/Chrome, 단일 스레드) | 설치·exe 실행이 막힌 학교 |
| 테스트 | 애드온 없는 자체 실행기 + 헤드리스 CI | 의존성 최소 |
| 저장 | `user://` + **진도 코드** | 복원 프로그램 대응 |
| 협업 | **WebSocket + JSON, push/fetch 할 때만 통신**. 서버 = 같은 프로젝트 헤드리스 실행 | [협업 설계](MULTIPLAYER_DESIGN.md) |

### 1.1 Web(TypeScript) 대비 무엇이 달라지나
| 항목 | 변화 | 대응 |
|---|---|---|
| 오프라인 실행 | 웹 내보내기는 `file://`(더블클릭)로 실행 불가 | **Windows exe**가 오프라인판 역할 |
| exe 차단 학교 | exe가 막히면 오프라인판을 못 씀 | 웹 내보내기를 학교·교육청 서버 또는 GitHub Pages에 올림 (전산 담당과 사전 협의) |
| 웹 첫 로딩 용량 | 엔진 파일(wasm) 포함으로 수십 MB (압축 시 크게 줄어듦) | P0에서 실측. 목표: 압축 전송 20MB 이하, 학교망 첫 로딩 20초 이내 |
| 웹 한글 입력 | 브라우저 안 Godot 입력창의 IME 동작 검증 필요 | **P0 최우선 검증**. 문제 시 Windows exe를 1순위 배포로 |
| UI 제작 | HTML보다 노드 조립이 필요 | Control 노드로 충분. 공용 UI 컴포넌트를 먼저 만든다 |
| 장점 | 마을 연출·애니메이션·타일맵이 쉬움, 무료(MIT), 텍스트 기반 씬 파일 → Git과 궁합 좋음 | 게임 소스 자체를 수업 Fork·PR 실습 자료로 활용 |

---

## 2. 계층 구조

```
┌───────────────────────────────────────────────────────────┐
│ scenes/  (Node 사용)                                         │
│  화면·연출: 마을, 커밋 그래프, 터미널, 포장대, 미니맵, 힌트     │
├───────────────────────────────────────────────────────────┤
│ stage/   (RefCounted, Node 금지)                             │
│  스테이지 로더, 판정 DSL, 힌트 단계, 별점, NPC 트리거          │
├───────────────────────────────────────────────────────────┤
│ core/    (RefCounted, Node 금지, 엔진 API 최소)              │
│  Git 시뮬레이터, 건물 파일, 진도 코드, 한/영 감지              │
└───────────────────────────────────────────────────────────┘
```

**규칙**
1. `core/`와 `stage/`는 `Node`를 상속하지 않는다 → 헤드리스 테스트에서 화면 없이 실행된다.
2. `core/` 스크립트는 `class_name`을 쓰지 않고 **`preload` 상수로 참조**한다. 처음 받은 저장소에서 편집기를 열기 전에도 헤드리스 테스트가 돌게 하기 위해서다.
3. 화면은 **Git 상태를 직접 바꾸지 않는다.** 바꾸는 길은 두 개뿐이다.
   - 명령: `Session.run_command("git commit -m ...")`
   - 마을 편집: `Session.edit_building(path, props)` (건물 파일을 쓰는 것과 같음)
4. 화면은 `Session.world_changed(events)` 신호를 받아 다시 그린다.

---

## 3. 폴더 구조

```
game/
├─ project.godot
├─ core/
│  ├─ hangul_keys.gd          ✅ 한/영 감지 (작성됨)
│  ├─ building_file.gd        ✅ 건물 파일 형식 (작성됨)
│  ├─ progress_code.gd        진도 코드 (12자)
│  ├─ net/                    ✅ 협업 통신: protocol.gd, room_server.gd, room_client.gd (MULTIPLAYER_DESIGN.md)
│  └─ git/
│     ├─ world.gd             World: cwd, repos, hub, clock, 이벤트 기록
│     ├─ repo.gd              Repo: objects, heads, remoteRefs, head, index, worktree…
│     ├─ objects.gd           blob·commit 생성, 해시(SHA-1)
│     ├─ diff.gd              Myers diff, 통합 diff 출력
│     ├─ merge.gd             merge base, 파일 단위 판정, diff3, 충돌 표시자
│     ├─ hub.gd               허브 섬(bare 저장소 모음)
│     ├─ npc.gd               NPC 동료 스크립트 실행기
│     ├─ parser.gd            입력 해석 (따옴표, 별칭, 오타 교정)
│     ├─ messages.gd          실제 Git 출력 문구 모음
│     └─ commands/            명령 1개 = 파일 1개
│        ├─ cmd_init.gd  cmd_status.gd  cmd_add.gd  cmd_commit.gd  cmd_log.gd …
├─ stage/
│  ├─ stage_loader.gd         JSON → 초기 World
│  ├─ goal_dsl.gd             판정 DSL 평가기
│  ├─ hints.gd · stars.gd · npc_triggers.gd
├─ content/
│  ├─ stages/                 1-1.json … 5-B.json
│  └─ text/ko.json            대사·힌트·오류 해설
├─ scenes/
│  ├─ main/                   타이틀, 스테이지 선택, 진도 코드 입력
│  ├─ stage/                  스테이지 화면 (아래 컴포넌트 조립)
│  ├─ ui/                     terminal, commit_graph, staging_tray, four_spaces, conflict_editor, hint_panel
│  ├─ village/                마을 타일맵, 건물 그리기
│  └─ spike/                  ✅ P0 스파이크 (검증 후 삭제)
├─ assets/  fonts/ art/ sfx/
├─ autoload/
│  └─ session.gd              현재 World·스테이지, 이벤트 신호, 저장
└─ tests/
   ├─ run_tests.gd            ✅ 실행기 · test_case.gd ✅
   ├─ test_*.gd               ✅ 2개 작성됨
   └─ vectors/*.json          시뮬레이터 공용 테스트 벡터
tools/
└─ difftest/                  실제 git 대조 (Python): 같은 벡터를 실제 git과 Godot 헤드리스로 실행 후 비교
```

---

## 4. 시뮬레이터 명세 → GDScript 대응

| 명세 (TypeScript 표기) | GDScript |
|---|---|
| `string` 해시 | `String` (40자리 hex) |
| `Map`, `Record` | `Dictionary` |
| `Head` (branch / detached) | `{"kind": "branch", "name": "main"}` / `{"kind": "detached", "commit": "<H>"}` |
| `CommitObj` | `{"type": "commit", "tree": {...}, "parents": [...], "message": "", "author": "", "time": 0}` |
| SHA-1 | `String.sha1_text()` (내용 문자열 → 40자리) |
| 불변 업데이트 / 되감기 | 명령 실행 전 `world.to_dict().duplicate(true)` 스냅샷 (저장소가 작아 비용 무시 가능) |
| 이벤트 | `Array[Dictionary]` — `{"type": "Committed", "hash": ..., ...}` |
| 결과 | `{"stdout": "", "stderr": "", "exit_code": 0, "error_code": "", "events": []}` |

- **World는 언제나 Dictionary로 직렬화 가능**해야 한다 (저장, 되감기, 테스트 비교, 진도 코드 검증).
- 정렬이 필요한 곳(트리 항목, 브랜치 목록)은 항상 `keys().sort()` 후 사용 → 해시 재현성.

---

## 5. 화면 컴포넌트 ↔ Godot 노드

| 컴포넌트 | 노드 구성 | 비고 |
|---|---|---|
| 터미널 | `RichTextLabel`(출력) + `LineEdit`(입력) | ↑↓ 기록, Tab 자동완성, 한/영 감지 ✅ 스파이크 |
| 커밋 그래프(나무) | `Control._draw()` + `ScrollContainer` | 브랜치별 세로 줄 배치, 색+아이콘+선 모양 3중 표시 ✅ 스파이크 |
| 마을 | `TileMapLayer`(아이소메트릭) + 건물 `Sprite2D` | 건물 파일 → 그림. 파싱 실패 시 깨진 건물 셰이더 |
| 포장대 | `HBoxContainer` + 드래그 앤 드롭 | 하이브리드 모드에서 드롭 = `git add` 입력 |
| 4개 공간 미니맵 | `HBoxContainer` 4칸 + `Tween` | 변경 아이콘이 공간 사이를 이동 |
| 충돌 편집기 | 비주얼: 버튼 3개 / 텍스트: `CodeEdit` | `CodeEdit`에 표시자 줄 강조 |
| 깃토리 힌트 | `PanelContainer` + `RichTextLabel` | 3단계 힌트 |
| 허브 섬 화면 | 별도 `Control` (원격 브랜치만 표시) | 로컬 그래프와 나란히 |

---

## 6. 한글 처리

| 항목 | Windows exe | 웹 내보내기 |
|---|---|---|
| 글꼴 | `SystemFont`로 맑은 고딕 사용 (내장 불필요) | **글꼴 파일 내장 필수** (브라우저 안에서는 시스템 글꼴을 못 씀) |
| 터미널 고정폭 | D2Coding(오픈 폰트 라이선스) 파일 내장 권장 | 동일 |
| 입력(IME) | Godot의 Windows IME 지원 사용 | **P0 최우선 검증** |
| 용량 | — | 한글 글꼴은 크므로 사용 글자(완성형 2,350자 + 영문·기호)로 줄인 파일 사용 |

---

## 7. 저장과 진도 코드

| 위치 | 경로 | 복원 프로그램 |
|---|---|---|
| Windows exe | `%APPDATA%\Godot\app_userdata\Commit Craft\` | 재부팅 시 지워짐 |
| 웹 | 브라우저 저장소(IndexedDB) | 정책에 따라 지워짐 |

- 클리어할 때마다 **진도 코드**를 화면에 보여주고 복사 버튼을 제공한다 ([Windows 실행 환경 2.2](WINDOWS_ENVIRONMENT.md)).
- 저장 실패는 게임 진행을 막지 않는다.

---

## 8. 내보내기(Export) 설정

> 내보내기 템플릿은 편집기 메뉴 **편집기 → 내보내기 템플릿 관리**에서 4.7.2용을 내려받는다. 설정 파일(`export_presets.cfg`)은 P0에서 편집기로 만들고 저장소에 커밋한다.

| 프리셋 | 핵심 설정 |
|---|---|
| **Windows Desktop** | PCK 내장(단일 exe), 64비트, 콘솔 창 끔, 아이콘 지정. 코드 서명이 없으면 Windows "PC 보호" 경고가 뜰 수 있음 → 교사 안내문에 "추가 정보 → 실행" 설명 |
| **Web** | 스레드 지원 끔(단일 스레드 → 특수 서버 헤더 불필요, GitHub Pages 가능), 글꼴 내장, 압축 전송 확인 |

---

## 9. 테스트와 CI

| 종류 | 방법 | 상태 |
|---|---|---|
| 단위 테스트 | `godot --headless --path game --script res://tests/run_tests.gd` | ✅ 실행기·테스트 2개 작성 |
| CI | `.github/workflows/godot-tests.yml` — Godot 4.7.2 리눅스판을 받아 헤드리스 실행, `RESULT: ... failed=0` 확인 | ✅ 작성 |
| 테스트 벡터 | `tests/vectors/*.json` (시뮬레이터 명세 7.1 형식) | P1 |
| 실제 Git 대조 | `tools/difftest/` (Python): 같은 벡터를 ① 실제 git ② Godot 헤드리스로 실행해 결과 비교 | P1 |
| 스테이지 자동 검증 | 스테이지 명세 0.5 (모범 해답 자동 클리어) — 헤드리스 실행 | P3 |

---

## 10. 개발 환경 (Windows PC)

| 도구 | 용도 |
|---|---|
| Godot 4.7.2 (압축 해제만, 설치 불필요) | 편집기 |
| Git for Windows | 버전 관리 (이 프로젝트 자체도 게임이 가르치는 방식으로: 브랜치 → PR → 리뷰) |
| (선택) VS Code + Godot 확장 | 스크립트 편집 |

- 저장소 루트 `.gitattributes`가 줄바꿈을 LF로 고정한다 → Windows에서도 가짜 변경이 생기지 않는다.
- `.godot/` 폴더(편집기 캐시)는 커밋하지 않는다 (`.gitignore`).

### 코딩 규칙
- 모든 변수·함수에 **정적 타입** 표기 (`var x: int`, `func f() -> String`)
- 들여쓰기 탭, 파일 이름 `snake_case.gd`
- 주석·문구는 한국어, 실제 Git 출력 문구는 영어 원문 그대로 `messages.gd`에 모음
- 화면 노드 구성은 가능하면 **코드로** 만든다 (.tscn 충돌을 줄이고 Git diff를 읽기 쉽게)

---

## 11. Godot 관련 위험

| 위험 | 신호 | 대응 |
|---|---|---|
| 웹 내보내기 한글 입력 문제 | P0에서 끝 글자 중복·조합 깨짐 | Windows exe를 1순위 배포로 전환, 웹은 보조 |
| 학교에서 exe 실행 차단 | P0에서 실행 불가 | 웹 내보내기를 교내 서버에 배포 |
| 웹 첫 로딩이 김 | 학교망에서 30초 이상 | 압축 전송 확인, 로딩 화면에 진행률·안내 |
| GDScript 성능 | 명령 1개 처리 50ms 이상 | 저장소가 작아 가능성 낮음. 병목 함수만 최적화 |
| 엔진 업데이트로 인한 깨짐 | — | 4.7.2 고정, 학기 중 업그레이드 금지 |
| Godot 경험자 부족 | 진행 지연 | 공식 문서 + AI 코딩 도구, 화면 컴포넌트를 작은 단위로 나눠 개발 |
