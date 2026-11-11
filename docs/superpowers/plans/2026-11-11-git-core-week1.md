# Git 코어 1주차 (init/add/commit/status/log + 테스트 벡터) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 구현 계획서 P1 1주차 — Git 시뮬레이터의 데이터 모델과 `init`/`add`/`commit`/`status`/`log`, 공용 테스트 벡터 형식과 실행기를 만든다.

**Architecture:** World는 언제나 직렬화 가능한 `Dictionary` 하나이고, 모든 로직은 `game/core/git/`의 정적 함수(`extends RefCounted`, `class_name` 없음, `preload` 참조)다. 유일한 진입점은 `git.gd`의 `run(world, input)`이며 world를 제자리에서 바꾸고 결과 사전을 돌려준다(되감기는 호출 측이 `world.duplicate(true)`로 스냅샷). 명령 1개 = `commands/cmd_*.gd` 1개. 검증은 JSON 테스트 벡터가 주이고 단위 테스트는 순수 함수(해시·토큰·ignore·줄 통계)에만 쓴다.

**Tech Stack:** Godot 4.7.1 표준판, GDScript(정적 타입), 자체 헤드리스 실행기 `game/tests/run_tests.gd`.

**Spec:** [docs/GIT_SIMULATOR_SPEC.md](../../GIT_SIMULATOR_SPEC.md) (0~4.5장, 6장, 7.1장), [docs/GODOT_ARCHITECTURE.md](../../GODOT_ARCHITECTURE.md) (2~4장, 10장 코딩 규칙)

## 범위 밖 (다음 계획)

- `tools/difftest` 실제 Git 대조 도구: 이 PC에 Python이 없어 로컬 검증 불가 → 별도 계획. 이번 벡터의 기대값은 2026-11-11 실제 Git(2.56, `LANG=C`)으로 직접 실행해 수집한 출력이다.
- `log --graph`/`--all`, upstream·병합 중 status 섹션, `show`/`diff`/`restore`/`branch`/`switch`/`merge` (2주차), `cd`/`ls`/`cat`·오타 교정·`config` (3주차).
- cwd가 저장소 하위 폴더일 때의 상대 경로 표시: `cd` 도입(3주차)과 함께 구현. 이번에는 cwd == 저장소 루트만 다룬다.

## Global Constraints

- 테스트 명령(저장소 루트 `d:\Git`, 이하 `$GODOT` = `D:\Godot\Godot_v4.7.1-stable_win64_console.exe`): `$GODOT --headless --path game --script res://tests/run_tests.gd` → 마지막에 `RESULT: passed=N failed=0`.
- `core/`는 `Node` 금지, `class_name` 금지, 다른 스크립트는 `const X := preload("res://core/git/x.gd")`로 참조. 모든 변수·함수에 정적 타입. 들여쓰기 탭. 주석은 한국어.
- 실제 Git 출력 문구는 영어 원문 그대로 `messages.gd`에만 둔다. 문구를 꾸며내지 않는다 — 이 계획에 없는 문구가 필요하면 실제 Git으로 실행해 확인한다.
- 정렬이 필요한 곳(트리 항목, 경로 목록, 브랜치 목록)은 항상 `keys()` → `sort()` 후 사용.
- 줄 끝은 LF, 한글 경로는 이스케이프 없이 표시.
- 금지 사항(명세 1.2): 커밋은 전체 스냅샷(`tree` 평면 맵)으로 저장. 충돌 표시자가 남은 파일의 add/commit을 막지 않는다.
- 새 `.gd` 파일을 만든 태스크는 커밋 전에 `$GODOT --headless --path game --import`를 실행해 생성된 `.gd.uid`를 함께 커밋한다.
- 새 테스트 스위트는 `game/tests/run_tests.gd`의 `TEST_FILES`에 등록한다. `test_scripts_compile.gd`가 `res://core` 전체를 컴파일 검사한다.
- `game/project.godot`의 현재 미커밋 변경(로컬 전용 godot_ai 애드온 autoload·플러그인)은 **커밋하지 않는다** (`git add`에 넣지 말 것).
- 브랜치: `feature/git-core-week1`. 커밋 메시지는 한국어 또는 영어로 대상·목적을 명확히.

## 이 계획에서 확정한 설계 결정 (명세가 열어 둔 부분)

| 항목 | 결정 |
|---|---|
| World | `{"cwd": String, "fs": {절대경로: 내용}, "repos": {경로: Repo}, "hub": {"repos": {}}, "clock": int, "config": {...}, "log": []}` |
| 파일 시스템 | 명세 3장의 `Repo.worktree` 대신 **`world.fs` 하나**에 모든 파일을 둔다(`git init` 전에 만든 파일, clone 대상 폴더를 다루기 위함). 저장소의 worktree = `fs` 중 `repo.path + "/"`로 시작하는 항목. 명세 3장에 이 대응을 한 줄 추가한다(Task 8). |
| 전역 설정 | `world.config` = `{"user.name": "플레이어", "user.email": "player@versionland.example", "init.defaultBranch": "main"}` (`--global`은 저장소를 넘나들어야 하므로 World에 둠) |
| Repo | `{"path", "objects": {}, "heads": {}, "remoteRefs": {}, "head": {"kind": "branch", "name": "main"}, "index": {}, "remotes": {}, "upstream": {}}`. index 항목 `{"kind": "normal", "blob": H}` |
| 커밋 객체 | `{"type": "commit", "tree": {경로: H}, "parents": [], "message": "", "author": "이름 <이메일>", "time": int}` |
| 가상 시계 | 기본 시작 `1772409600` (= Mon Mar 2 09:00:00 2026 +0900). 커밋 직전에 `clock += 60` 후 그 값을 사용. 표시는 항상 `+0900`. |
| 기본 cwd | `/home/player/마을` |
| 해시 입력(바이트) | blob: `"blob" 0x00 내용`. commit: `"commit" 0x00` + 정렬된 경로마다 `tree <경로>\t<H>\n` + 부모마다 `parent <H>\n` + `author <author>\n` + `time <time>\n` + `\n` + message. NUL이 들어가므로 `String.sha1_text()`가 아니라 `PackedByteArray` + `HashingContext`(SHA1)를 쓴다. |
| 결과 | `{"stdout": "", "stderr": "", "exit_code": 0, "error_code": "", "events": []}`. events는 `world.log`에도 추가. 실패 시 `CommandError{code, input}` 이벤트 추가. |
| 종료 코드 | 실제 Git과 동일: 저장소 아님·pathspec·커밋 없음 log = 128, 커밋할 것 없음·ignored add·모르는 명령 = 1 |
| log 장식 | 터미널 실행 기준으로 `(HEAD -> main)` 장식을 표시한다 (명세 4.5). |

## Review Focus

1. 빈 입력·공백만·`git`만 입력 → 크래시 없이: 빈 입력은 출력 없음/exit 0, `git`만은 `usage: git <command> [<args>]`/exit 1. (Task 2)
2. 닫히지 않은 따옴표 `git commit -m "분수` → world 변화 없이 `E_PARSE`, exit 2, 한국어 안내. (Task 2)
3. 빈 커밋 메시지 `-m ""`·공백만 → 실제 Git 문구 `Aborting commit due to empty commit message.`, exit 1, `E_EMPTY_MESSAGE`, 커밋 생성 안 됨. (Task 6)
4. 경로 표기 변형: `./광장/분수.txt`, 폴더 지정 `광장`·`광장/`, 저장소 밖 `../x.txt` → 앞의 둘은 정상 동작, 마지막은 `fatal: ../x.txt: '../x.txt' is outside repository at '/home/player/마을'`/128/`E_OUTSIDE_REPO`. (Task 4)
5. 파일 끝 개행이 없는 내용·빈 파일 → 줄 통계가 마지막 줄을 1줄로 세고 빈 파일은 0줄, 해시·add·commit이 정상 동작. (Task 6)

---

### Task 1: 데이터 모델·해시·불변식

**Files:**
- Create: `game/core/git/objects.gd`, `game/core/git/world.gd`, `game/core/git/repo.gd`, `game/core/git/invariants.gd`
- Test: `game/tests/test_git_model.gd` (+ `run_tests.gd` 등록)

**Interfaces (Produces):**
- `objects.gd`: `static func blob_hash(content: String) -> String`, `static func commit_hash(commit: Dictionary) -> String`, `static func short(hash: String) -> String`(앞 7자리), `static func put_blob(repo: Dictionary, content: String) -> String`(objects에 저장 후 해시), `static func put_commit(repo: Dictionary, commit: Dictionary) -> String`
- `world.gd`: `static func create(options: Dictionary = {}) -> Dictionary` (옵션 키 `cwd`, `clock`, `user_name`; 위 결정 표의 기본값)
- `repo.gd`: `static func new_repo(path: String) -> Dictionary`, `static func find(world: Dictionary) -> Dictionary`(cwd 또는 그 조상 경로의 저장소, 없으면 `{}`), `static func worktree(world: Dictionary, repo: Dictionary) -> Dictionary`(상대경로→내용), `static func write_file(world, repo, rel_path: String, content: String) -> void`, `static func delete_file(world, repo, rel_path: String) -> void`, `static func head_commit(repo: Dictionary) -> String`(unborn이면 `""`), `static func head_tree(repo: Dictionary) -> Dictionary`(unborn이면 `{}`), `static func blob_content(repo: Dictionary, hash: String) -> String`
- `invariants.gd`: `static func check(world: Dictionary) -> PackedStringArray` — 명세 3.2의 1~3번 + "index의 normal blob과 모든 커밋 tree의 blob이 objects에 존재". 위반 설명 문자열 목록(없으면 빈 배열).

- [ ] **Step 1: 실패하는 테스트 작성** — `test_git_model.gd`

```gdscript
extends "res://tests/test_case.gd"

const Objects := preload("res://core/git/objects.gd")
const World := preload("res://core/git/world.gd")
const Repo := preload("res://core/git/repo.gd")
const Invariants := preload("res://core/git/invariants.gd")

func test_blob_hash_is_sha1_of_blob_nul_content() -> void:
	assert_eq(Objects.blob_hash(""), "48ede76ef68a65b7292840b4ad4d1f111359d82a")
	assert_eq(Objects.blob_hash("종류: 벤치\n"), "7977b88fb6809a96423a956e6e7adf2d48442812")

func test_commit_hash_is_deterministic_and_pinned() -> void:
	var root := {"type": "commit", "tree": {"광장/벤치.txt": "7977b88fb6809a96423a956e6e7adf2d48442812"},
		"parents": [], "message": "벤치 추가", "author": "플레이어 <player@versionland.example>", "time": 1772409660}
	assert_eq(Objects.commit_hash(root), "a8b87c7db56f22954bec7ad454d428d3dac76fc0")
	var child := {"type": "commit", "tree": {}, "parents": ["a8b87c7db56f22954bec7ad454d428d3dac76fc0"],
		"message": "벤치 철거", "author": "단비 <danbi@versionland.example>", "time": 1772409720}
	assert_eq(Objects.commit_hash(child), "0de8d3742da8680c5d553174bfb994edf9703e91")
	assert_eq(Objects.short("a8b87c7db56f22954bec7ad454d428d3dac76fc0"), "a8b87c7")

func test_tree_order_does_not_change_hash() -> void:
	var a := {"type": "commit", "tree": {"가.txt": "1", "나.txt": "2"}, "parents": [], "message": "m", "author": "a", "time": 1}
	var b := {"type": "commit", "tree": {"나.txt": "2", "가.txt": "1"}, "parents": [], "message": "m", "author": "a", "time": 1}
	assert_eq(Objects.commit_hash(a), Objects.commit_hash(b))

func test_world_defaults_and_serializable() -> void:
	var w := World.create()
	assert_eq(w["cwd"], "/home/player/마을")
	assert_eq(w["clock"], 1772409600)
	assert_eq(w["config"]["user.name"], "플레이어")
	assert_eq(JSON.parse_string(JSON.stringify(w))["cwd"], "/home/player/마을")
	assert_eq(World.create({"user_name": "단비"})["config"]["user.name"], "단비")

func test_repo_find_and_worktree_view() -> void:
	var w := World.create()
	assert_true(Repo.find(w).is_empty())
	w["fs"]["/home/player/마을/광장/분수.txt"] = "x\n"
	w["fs"]["/home/player/다른곳/a.txt"] = "y\n"
	var r := Repo.new_repo("/home/player/마을")
	w["repos"][r["path"]] = r
	assert_eq(Repo.find(w)["path"], "/home/player/마을")
	assert_eq(Repo.worktree(w, r), {"광장/분수.txt": "x\n"})
	assert_eq(Repo.head_commit(r), "")
	Repo.write_file(w, r, "a.txt", "1\n")
	Repo.delete_file(w, r, "광장/분수.txt")
	assert_eq(Repo.worktree(w, r), {"a.txt": "1\n"})
	w["cwd"] = "/home/player/마을/광장"
	assert_eq(Repo.find(w)["path"], "/home/player/마을")

func test_invariants_catch_dangling_ref() -> void:
	var w := World.create()
	var r := Repo.new_repo("/home/player/마을")
	w["repos"][r["path"]] = r
	assert_eq(Invariants.check(w).size(), 0, "unborn main은 정상")
	r["heads"]["main"] = "ffffffffffffffffffffffffffffffffffffffff"
	assert_true(Invariants.check(w).size() > 0)
```

- [ ] **Step 2: 실패 확인** — 테스트 명령 실행. 기대: `test_git_model.gd` 로드 실패 또는 FAIL.
- [ ] **Step 3: 네 파일 구현** (위 Interfaces와 결정 표대로).
- [ ] **Step 4: 통과 확인** — `RESULT: passed=25 failed=0` (기존 19 + 6).
- [ ] **Step 5: 커밋** — `git add game/core/git game/tests/test_git_model.gd* game/tests/run_tests.gd` → `Git 코어: 데이터 모델·결정적 해시·불변식`

---

### Task 2: 입력 토큰화 · 명령 분배 · `git init`

**Files:**
- Create: `game/core/git/parser.gd`, `game/core/git/messages.gd`, `game/core/git/git.gd`, `game/core/git/commands/cmd_init.gd`
- Test: `game/tests/test_git_run.gd`

**Interfaces:**
- Consumes: Task 1 전부.
- Produces:
  - `parser.gd`: `static func tokenize(input: String) -> Dictionary` → `{"ok": bool, "tokens": PackedStringArray}`. 공백 분리, `"…"`·`'…'` 안의 공백 보존, 따옴표 제거, `"` 안의 `\"` 이스케이프 지원, 닫히지 않으면 `ok=false`.
  - `git.gd`: `static func run(world: Dictionary, input: String) -> Dictionary`(결과 사전), `static func ok(stdout: String = "", events: Array = []) -> Dictionary`, `static func fail(exit_code: int, error_code: String, stderr: String, stdout: String = "") -> Dictionary` — 명령 파일들이 결과를 만들 때 사용.
  - 명령 파일 공통 시그니처: `static func run(world: Dictionary, args: PackedStringArray) -> Dictionary` (`args`는 `git <sub>` 뒤 토큰).
  - `messages.gd`: 영어 원문 상수·`%` 서식 문자열. 이후 태스크가 여기에 추가한다.
- `run` 동작: 토큰화 → 빈 입력은 `ok()` → 첫 토큰이 `git`이 아니면 `fail(127, "E_NOT_FOUND", "bash: <cmd>: command not found\n")` → 하위 명령 분배. `init` 외 명령은 저장소가 없으면 `fail(128, "E_NOT_A_REPO", "fatal: not a git repository (or any of the parent directories): .git\n")`. 명세 0장의 MVP 명령 중 아직 미구현인 것은 `fail(1, "E_UNSUPPORTED", "이 섬에서는 아직 봉인된 마법이야: git <sub>\n")`. 그 외는 `fail(1, "E_UNKNOWN_COMMAND", "git: '<sub>' is not a git command. See 'git --help'.\n")`. 실패 결과에는 `CommandError` 이벤트를 붙이고, 모든 이벤트를 `world.log`에 추가. 디버그 빌드(`OS.is_debug_build()`)에서는 실행 후 `Invariants.check`가 비어 있지 않으면 `push_error` 후 `fail(70, "E_INVARIANT", …)`.
- `init`: `Initialized empty Git repository in <cwd>/.git/\n`, 이벤트 `RepoInitialized{path}`. 이미 있으면 `Reinitialized existing Git repository in <cwd>/.git/\n`, 상태 변화·이벤트 없음.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_git_run.gd`

```gdscript
extends "res://tests/test_case.gd"

const Parser := preload("res://core/git/parser.gd")
const Git := preload("res://core/git/git.gd")
const World := preload("res://core/git/world.gd")

func test_tokenize_quotes_and_korean() -> void:
	assert_eq(Parser.tokenize("git commit -m \"분수 추가\"")["tokens"], PackedStringArray(["git", "commit", "-m", "분수 추가"]))
	assert_eq(Parser.tokenize("git  commit -m '벤치 \"둘\"'")["tokens"], PackedStringArray(["git", "commit", "-m", "벤치 \"둘\""]))
	assert_eq(Parser.tokenize("git commit -m \"a \\\"b\\\"\"")["tokens"], PackedStringArray(["git", "commit", "-m", "a \"b\""]))
	assert_eq(Parser.tokenize("git commit -m \"\"")["tokens"], PackedStringArray(["git", "commit", "-m", ""]))
	assert_eq(Parser.tokenize("   ")["tokens"], PackedStringArray())
	assert_eq(Parser.tokenize("git commit -m \"분수")["ok"], false)

func test_init_and_reinit() -> void:
	var w := World.create()
	var r := Git.run(w, "git init")
	assert_eq(r["stdout"], "Initialized empty Git repository in /home/player/마을/.git/\n")
	assert_eq(r["exit_code"], 0)
	assert_eq(r["events"][0]["type"], "RepoInitialized")
	assert_eq(w["repos"]["/home/player/마을"]["head"], {"kind": "branch", "name": "main"})
	var again := Git.run(w, "git init")
	assert_eq(again["stdout"], "Reinitialized existing Git repository in /home/player/마을/.git/\n")
	assert_eq(again["events"].size(), 0)

func test_errors_before_any_command_logic() -> void:
	var w := World.create()
	var before := w.duplicate(true)
	var not_repo := Git.run(w, "git status")
	assert_eq(not_repo["stderr"], "fatal: not a git repository (or any of the parent directories): .git\n")
	assert_eq(not_repo["exit_code"], 128)
	assert_eq(not_repo["error_code"], "E_NOT_A_REPO")
	assert_eq(not_repo["events"][0], {"type": "CommandError", "code": "E_NOT_A_REPO", "input": "git status"})
	assert_eq(Git.run(w, "git frobnicate")["stderr"], "git: 'frobnicate' is not a git command. See 'git --help'.\n")
	assert_eq(Git.run(w, "dir")["stderr"], "bash: dir: command not found\n")
	assert_eq(Git.run(w, "dir")["exit_code"], 127)
	assert_eq(Git.run(w, "git rebase main")["error_code"], "E_UNKNOWN_COMMAND")
	Git.run(w, "git init")
	assert_eq(Git.run(w, "git merge x")["error_code"], "E_UNSUPPORTED")
	before["log"] = w["log"]
	before["repos"] = w["repos"]
	assert_eq(w, before, "오류 명령은 log·init 외 상태를 바꾸지 않음")

func test_empty_git_only_and_unclosed_quote() -> void:
	var w := World.create()
	var empty := Git.run(w, "   ")
	assert_eq([empty["stdout"], empty["stderr"], empty["exit_code"]], ["", "", 0])
	var bare := Git.run(w, "git")
	assert_eq(bare["stdout"], "usage: git <command> [<args>]\n")
	assert_eq(bare["exit_code"], 1)
	var open := Git.run(w, "git commit -m \"분수")
	assert_eq(open["exit_code"], 2)
	assert_eq(open["error_code"], "E_PARSE")
	assert_eq(open["stderr"], "따옴표가 닫히지 않았어. 메시지 끝에 \" 를 붙여줘.\n")
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `RESULT: passed=29 failed=0`
- [ ] **Step 5: 커밋** — `Git 코어: 입력 토큰화, 명령 분배, git init`

---

### Task 3: 테스트 벡터 형식과 실행기

**Files:**
- Create: `game/tests/vector_runner.gd`, `game/tests/test_git_vectors.gd`, `game/tests/vectors/init.json`, `game/tests/vectors/README.md`
- Test: `game/tests/test_vector_runner.gd`

**Interfaces:**
- Consumes: `Git.run`, `World.create`, `Repo.*`, `Invariants.check`, `res://core/building_file.gd`의 `serialize`/`parse`.
- Produces: `vector_runner.gd`: `static func run_vector(vector: Dictionary) -> PackedStringArray`(실패 설명 목록, 통과면 빈 배열), `static func load_file(path: String) -> Array`. 벡터 파일 = 벡터 객체의 JSON 배열.
- 벡터 형식 (명세 7.1의 부분집합; 이후 주차에 `@hub`/`@npc`/`refs` 확장):

| 필드 | 의미 |
|---|---|
| `name` | 고유 이름 |
| `setup` | 문자열 배열. 일반 줄은 `Git.run`으로 실행하며 **exit 0이어야 함**(아니면 벡터 실패). `@write <경로> 키=값 …`: 건물 파일 쓰기(파일이 있으면 속성 병합, 없으면 새로 만듦 — `building_file.serialize`). `@raw <경로> <내용>`: 내용 그대로 쓰기(`\n` 두 글자는 개행으로 치환, 내용 생략 시 빈 파일). `@delete <경로>`: 파일 삭제. `@`줄의 경로는 저장소가 없어도 cwd 기준. |
| `run` | 검사 대상 명령 1개 (`@` 줄도 허용) |
| `expect.exitCode` / `errorCode` | 정확히 일치 (`errorCode` 생략 = 빈 문자열이어야 함) |
| `expect.stdout` / `stderr` | 정규화 후 전체 일치. `stdoutContains` / `stderrContains`: 부분 문자열 배열 |
| `expect.statusShort` | 실행 후 `git status -s`의 stdout과 전체 일치 (Task 5부터 사용) |
| `expect.index` | `{경로: 내용}` — index 전체와 일치 (blob 내용으로 비교) |
| `expect.worktree` | `{경로: 내용}` — 나열한 경로만 비교, 값 `null`은 "파일 없음" |
| `expect.head` | `{경로: 내용}` — HEAD 커밋 tree 전체와 일치 |
| `expect.log` | HEAD에서 첫 부모를 따라간 커밋 메시지 배열 (최신 먼저) |
| `expect.events` | `run`이 낸 이벤트 `type` 배열과 일치 |

- 정규화: 실제 stdout·stderr에서 40자리 hex → `<H>`, 그다음 단어 경계의 7자리 hex → `<h>` (정규식 `\b[0-9a-f]{40}\b`, `\b[0-9a-f]{7}\b`).
- 모든 setup·run 명령 뒤에 `Invariants.check(world)`가 비어 있어야 한다.
- `test_git_vectors.gd`: `res://tests/vectors/*.json`을 이름순으로 모두 읽어 실행, 실패마다 `"<파일>::<name> — <설명>"`을 `errors`에 추가, 끝에 `print("VECTORS: %d" % count)`. 이름 중복은 실패. 메서드는 `test_all_vectors` 하나.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_vector_runner.gd` (실행기 자체 검증)

```gdscript
extends "res://tests/test_case.gd"

const Runner := preload("res://tests/vector_runner.gd")

func test_passing_vector() -> void:
	var v := {"name": "init", "setup": ["@write 광장/분수.txt 종류=분수 색=파랑"], "run": "git init",
		"expect": {"exitCode": 0, "stdout": "Initialized empty Git repository in /home/player/마을/.git/\n",
			"worktree": {"광장/분수.txt": "종류: 분수\n\n색: 파랑\n", "없음.txt": null}, "index": {}, "events": ["RepoInitialized"]}}
	assert_eq(Runner.run_vector(v), PackedStringArray())

func test_mismatches_are_reported() -> void:
	var v := {"name": "bad", "setup": [], "run": "git init",
		"expect": {"exitCode": 1, "stdout": "x", "errorCode": "E_X", "worktree": {"a.txt": "1"}, "events": []}}
	assert_eq(Runner.run_vector(v).size(), 5)

func test_failing_setup_line_fails_vector() -> void:
	var v := {"name": "setup", "setup": ["git status"], "run": "git init", "expect": {"exitCode": 0}}
	assert_eq(Runner.run_vector(v).size(), 1)

func test_write_merges_and_raw_and_delete() -> void:
	var v := {"name": "fs", "setup": ["@write a.txt 종류=집 색=파랑", "@write a.txt 색=빨강", "@raw b.txt 1\\n2", "@raw c.txt", "@raw d.txt x", "@delete d.txt"],
		"run": "git init", "expect": {"exitCode": 0,
			"worktree": {"a.txt": "종류: 집\n\n색: 빨강\n", "b.txt": "1\n2", "c.txt": "", "d.txt": null}}}
	assert_eq(Runner.run_vector(v), PackedStringArray())

func test_hash_normalization() -> void:
	assert_eq(Runner.normalize("[main a8b87c7] x\ncommit a8b87c7db56f22954bec7ad454d428d3dac76fc0\n"), "[main <h>] x\ncommit <H>\n")
```

  (`normalize(text: String) -> String`도 공개 함수로 둔다.)

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 실행기 구현 + `init.json` 작성** — 벡터 4개: ① 빈 폴더 init(위 stdout) ② 파일이 있는 폴더 init — worktree 유지·index `{}` ③ 재초기화 stdout `Reinitialized existing Git repository in /home/player/마을/.git/\n`, events `[]` ④ init 전 `git status` → 128, `E_NOT_A_REPO`, 위 stderr. `README.md`에는 위 형식 표를 옮겨 적는다.
- [ ] **Step 4: 통과 확인** — `VECTORS: 4`, `RESULT: passed=35 failed=0`
- [ ] **Step 5: 커밋** — `테스트 벡터 형식·실행기와 init 벡터`

---

### Task 4: `.gitignore`와 `git add`

**Files:**
- Create: `game/core/git/ignore.gd`, `game/core/git/commands/cmd_add.gd`, `game/tests/vectors/add.json`
- Modify: `game/core/git/git.gd`(분배), `game/core/git/messages.gd`, `game/core/git/repo.gd`
- Test: `game/tests/test_git_ignore.gd`

**Interfaces:**
- Produces:
  - `ignore.gd`: `static func parse(content: String) -> PackedStringArray`(빈 줄·`#` 줄 제거, 앞뒤 공백 제거), `static func is_ignored(patterns: PackedStringArray, path: String) -> bool`, `static func for_repo(world: Dictionary, repo: Dictionary) -> PackedStringArray`(worktree 루트의 `.gitignore`, 없으면 빈 배열).
  - 패턴 규칙: `/` 없는 패턴(`메모.txt`, `*.log`)은 경로의 **어느 구성 요소든** 일치하면 무시(`*.확장자`는 접미 비교). 끝이 `/`인 패턴(`비밀/`)은 **폴더 구성 요소**(마지막 구성 요소 제외)와 일치할 때만. 중간에 `/`가 있는 패턴(`광장/분수.txt`, `광장/창고/`)은 루트 기준 전체 경로 일치 또는 그 폴더 아래.
  - `repo.gd`: `static func resolve_pathspec(world: Dictionary, repo: Dictionary, spec: String) -> String` — `./` 제거·`..` 정리·끝 `/` 제거 후 저장소 기준 상대 경로(루트는 `""`), 저장소 밖이면 `"<outside>"`.
- `git add` 동작 (명세 4.3):
  - 인자 없음: stdout `Nothing specified, nothing added.\n` + stderr `hint: Maybe you wanted to say 'git add .'?\n`, exit 0 (실제 Git 2.43 동작. 구현 전 `git add`를 실제로 실행해 문구·스트림 확인).
  - pathspec마다 대상 = (worktree ∪ index) 중 그 경로이거나 그 폴더 아래인 경로. `.`/`""`는 전체. 대상 중 **index에 없고 무시되는** 파일은 제외.
  - 제외 후 대상이 없을 때: 무시된 파일을 직접 지정했으면 exit 1, `E_IGNORED`, stderr `The following paths are ignored by one of your .gitignore files:\n<경로>\nhint: Use -f if you really want to add them.\nhint: Turn this message off by running\nhint: "git config advice.addIgnoredFile false"\n`. 아니면 exit 128, `E_PATHSPEC`, `fatal: pathspec '<입력 그대로>' did not match any files\n`. 단, `.`은 대상이 없어도 성공.
  - 저장소 밖: exit 128, `E_OUTSIDE_REPO`, `fatal: <입력>: '<입력>' is outside repository at '<repo.path>'\n`.
  - **오류가 하나라도 있으면 index를 전혀 바꾸지 않는다** (실제 Git과 동일).
  - 반영: worktree에 있으면 `put_blob` 후 index 갱신, 없으면 index에서 제거. 실제로 index가 바뀐 경로가 있으면 `Staged{paths}`(정렬). 이번에 스테이징된 내용에 충돌 표시자(`building_file.has_conflict_markers`)가 있으면 `MarkersStaged{paths}` 추가.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_git_ignore.gd`

```gdscript
extends "res://tests/test_case.gd"

const Ignore := preload("res://core/git/ignore.gd")

func test_parse_skips_comments_and_blanks() -> void:
	assert_eq(Ignore.parse("*.log\n\n# 주석\n 비밀/ \n메모.txt\n"), PackedStringArray(["*.log", "비밀/", "메모.txt"]))

func test_patterns() -> void:
	var p := PackedStringArray(["*.log", "비밀/", "메모.txt", "광장/창고/"])
	for path in ["x.log", "광장/y.log", "비밀/a.txt", "시장/비밀/b.txt", "메모.txt", "광장/메모.txt", "광장/창고/상자.txt"]:
		assert_true(Ignore.is_ignored(p, path), path)
	for path in ["x.txt", "비밀", "광장/비밀", "메모.txt.bak", "시장/창고/상자.txt", "log", "광장/분수.txt"]:
		assert_true(not Ignore.is_ignored(p, path), path)
```

  그리고 `add.json` 벡터 14개 (F = `@write 광장/분수.txt 종류=분수 색=파랑 층수=1 장식=꽃`, 내용 `"종류: 분수\n\n색: 파랑\n\n층수: 1\n\n장식: 꽃\n"`):

| # | name | 핵심 setup → run | expect |
|---|---|---|---|
| 1 | add 한 파일 | init, F → `git add 광장/분수.txt` | exit 0, stdout `""`, index = F 내용, events `["Staged"]` |
| 2 | add . 전체 | init, F, `@write 시장/노점.txt 종류=노점` → `git add .` | index 두 파일 |
| 3 | add 폴더 | 위와 같음 → `git add 광장` | index 분수만 |
| 4 | add 폴더(끝 슬래시)·./ | → `git add ./광장/` | index 분수만 |
| 5 | 없는 경로 | init → `git add 없음.txt` | 128, `E_PATHSPEC`, stderr `fatal: pathspec '없음.txt' did not match any files\n`, events `["CommandError"]` |
| 6 | 오류 시 아무것도 스테이징 안 됨 | init, F → `git add 광장/분수.txt 없음.txt` | 128, index `{}` |
| 7 | add 시점 내용 고정 | init, F, add, `@write 광장/분수.txt 색=빨강` → `git status` 대신 run=`@raw 더미.txt` | index 분수 = 파랑, worktree 분수 = 빨강 |
| 8 | 다시 add하면 최신 내용 | 7 + → `git add 광장/분수.txt` | index 분수 = 빨강 |
| 9 | 삭제 반영 | init, F, add, `@delete 광장/분수.txt` → `git add .` | index `{}`, events `["Staged"]` |
| 10 | add . 은 무시 파일 제외 | init, `@raw .gitignore *.log\n비밀/\n`, `@raw x.log b`, `@raw 비밀/a.txt a`, F → `git add .` | index = `.gitignore`와 분수만 |
| 11 | 무시 파일 직접 지정 | 10의 setup → `git add x.log` | 1, `E_IGNORED`, stderrContains `["The following paths are ignored by one of your .gitignore files:\nx.log\n"]`, index `{}` |
| 12 | 추적 중인 파일은 무시돼도 계속 추적 | init, `@raw x.log a`, `git add x.log`, `@raw .gitignore *.log\n`, `@raw x.log b` → `git add .` | index x.log = `b`, `.gitignore` 포함 |
| 13 | 충돌 표시자 add 허용 | init, `@raw a.txt <<<<<<< HEAD\n색: 노랑\n=======\n색: 빨강\n>>>>>>> x\n` → `git add a.txt` | exit 0, events `["Staged", "MarkersStaged"]` |
| 14 | 저장소 밖 경로 | init → `git add ../x.txt` | 128, `E_OUTSIDE_REPO`, stderr `fatal: ../x.txt: '../x.txt' is outside repository at '/home/player/마을'\n` |
| 15 | 변화 없는 add는 이벤트 없음 | init, F, add → `git add .` | exit 0, events `[]` |

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `VECTORS: 19`, `failed=0`
- [ ] **Step 5: 커밋** — `Git 코어: .gitignore와 git add`

---

### Task 5: `git status` (긴 형식 · `-s`)

**Files:**
- Create: `game/core/git/status.gd`, `game/core/git/commands/cmd_status.gd`, `game/tests/vectors/status.json`
- Modify: `git.gd`, `messages.gd`

**Interfaces:**
- Produces `status.gd`:
  - `static func compute(world: Dictionary, repo: Dictionary) -> Dictionary` → `{"staged": [{"path", "change"}], "unstaged": [{"path", "change"}], "untracked": [String]}`. `change` ∈ `"new file"`, `"modified"`, `"deleted"`. 각 목록은 경로순. UI도 이 구조를 쓴다(명세 부록 A).
  - `static func format_long(repo: Dictionary, st: Dictionary, for_commit: bool = false) -> String`
  - `static func format_short(st: Dictionary) -> String`
- 계산: staged = HEAD tree ↔ index, unstaged = index ↔ worktree(무시 여부와 무관), untracked = worktree에 있고 index에 없고 무시되지 않는 파일. untracked 표시는 그 파일의 조상 폴더 중 **index 경로가 하나도 없는 가장 얕은 폴더**가 있으면 `폴더/`로 접고(중복 제거), 없으면 파일 경로.
- 긴 형식 (탭 = `\t`, 실제 Git 출력 그대로):
  - 첫 줄 `On branch <b>\n`. unborn이면 이어서 `\nNo commits yet\n\n` (`for_commit`이면 `No commits yet` 대신 `Initial commit`).
  - staged 섹션: `Changes to be committed:\n` + 힌트(unborn: `  (use "git rm --cached <file>..." to unstage)\n`, 아니면 `  (use "git restore --staged <file>..." to unstage)\n`) + 줄마다 `\t<라벨><경로>\n` + `\n`. 라벨은 12칸 고정: `new file:   `, `modified:   `, `deleted:    `.
  - unstaged 섹션: `Changes not staged for commit:\n` + `  (use "git add <file>..." to update what will be committed)\n`(삭제 항목이 있으면 `git add/rm <file>...`) + `  (use "git restore <file>..." to discard changes in working directory)\n` + 줄들 + `\n`.
  - untracked 섹션: `Untracked files:\n  (use "git add <file>..." to include in what will be committed)\n` + `\t<경로>\n`들 + `\n`.
  - 끝줄: staged가 있으면 없음. 없고 unstaged가 있으면 `no changes added to commit (use "git add" and/or "git commit -a")\n`. 없고 untracked만 있으면 `nothing added to commit but untracked files present (use "git add" to track)\n`. 모두 없으면 unborn은 `nothing to commit (create/copy files and use "git add" to track)\n`, 아니면 `nothing to commit, working tree clean\n`.
- 짧은 형식: 추적 경로(staged ∪ unstaged)를 경로순으로 `XY <경로>\n` — X: staged의 `A`/`M`/`D` 또는 공백, Y: unstaged의 `M`/`D` 또는 공백. 그 뒤 untracked를 `?? <경로>\n`.
- `cmd_status`: 인자 없음 → 긴 형식, `-s`/`--short` → 짧은 형식, 그 외 옵션 → `fail(129, "E_UNSUPPORTED_OPTION", "error: unknown option `<옵션에서 앞의 - 제거>'\n")`. 이벤트 없음.

- [ ] **Step 1: 벡터 작성** — `status.json` 벡터 14개. 기대 stdout은 아래 실제 Git 출력(2026-11-11 수집)을 그대로 쓴다. B = `@write 광장/벤치.txt 종류=벤치`, N = `@write 시장/노점.txt 종류=노점`.

| # | name | setup → run | expect.stdout |
|---|---|---|---|
| 1 | 빈 저장소 | init → `git status` | `On branch main\n\nNo commits yet\n\nnothing to commit (create/copy files and use "git add" to track)\n` |
| 2 | 빈 저장소 -s | init → `git status -s` | `""` |
| 3 | 새 폴더는 폴더로 접힘 | init, F, B, N → `git status` | `On branch main\n\nNo commits yet\n\nUntracked files:\n  (use "git add <file>..." to include in what will be committed)\n\t광장/\n\t시장/\n\nnothing added to commit but untracked files present (use "git add" to track)\n` |
| 4 | 위 -s | → `git status -s` | `?? 광장/\n?? 시장/\n` |
| 5 | 일부만 add (unborn) | 3 + `git add 광장/분수.txt` → `git status` | `On branch main\n\nNo commits yet\n\nChanges to be committed:\n  (use "git rm --cached <file>..." to unstage)\n\tnew file:   광장/분수.txt\n\nUntracked files:\n  (use "git add <file>..." to include in what will be committed)\n\t광장/벤치.txt\n\t시장/\n\n` |
| 6 | 위 -s | → `git status --short` | `A  광장/분수.txt\n?? 광장/벤치.txt\n?? 시장/\n` |
| 7 | 무시 파일은 안 보임 | init, `@raw .gitignore *.log\n비밀/\n`, `@raw x.log b`, `@raw 비밀/a.txt a` → `git status -s` | `?? .gitignore\n` |
| 8 | 모르는 옵션 | init → `git status --bogus` | 129, `E_UNSUPPORTED_OPTION`, stderr ``error: unknown option `bogus'\n`` |

  커밋이 필요한 6개(9~14)는 Task 6에서 `status.json`에 추가한다.

- [ ] **Step 2: 실패 확인** (`E_UNSUPPORTED`로 실패)
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `VECTORS: 27`, `failed=0`
- [ ] **Step 5: 커밋** — `Git 코어: git status (긴 형식, -s)`

---

### Task 6: 줄 통계와 `git commit`

**Files:**
- Create: `game/core/git/diff.gd`, `game/core/git/commands/cmd_commit.gd`, `game/tests/vectors/commit.json`
- Modify: `git.gd`, `messages.gd`, `game/tests/vectors/status.json`
- Test: `game/tests/test_git_diff.gd`

**Interfaces:**
- Produces:
  - `diff.gd`: `static func split_lines(content: String) -> PackedStringArray`(빈 문자열 → 0줄, 끝 개행은 줄을 만들지 않음, 끝 개행 없는 마지막 줄도 1줄), `static func line_stats(old: String, new: String) -> Dictionary` → `{"ins": int, "del": int}` = 줄 단위 LCS 기준(`ins = 새 줄 수 − LCS`, `del = 옛 줄 수 − LCS`). Myers hunk 계산은 2주차에 이 파일에 추가한다.
  - `cmd_commit` (명세 4.4). 지원 옵션: `-m <msg>`, `-a`, `-am <msg>`, `-a -m <msg>`. 그 외 옵션은 `E_UNSUPPORTED_OPTION`(129).
- 판정 순서 (실제 Git 순서):
  1. `-a`면 index의 모든 경로를 worktree 내용으로 갱신(없어진 파일은 index에서 제거). **새 파일은 추가하지 않는다.**
  2. HEAD tree == index tree → exit 1, `E_NOTHING_TO_COMMIT`, stdout = `Status.format_long(repo, st, true)`. (`-a`로 갱신한 index는 그대로 둔다 — 변화가 없었다는 뜻이므로 무해.)
  3. `-m` 없음 → exit 1, `E_NEED_MESSAGE`, stderr `실제 Git은 여기서 에디터를 열어. 이 섬에선 -m "메시지"로 적어줘.\n`. 이때 1번에서 바꾼 index는 되돌린다.
  4. 메시지가 비었거나 공백뿐 → exit 1, `E_EMPTY_MESSAGE`, stderr `Aborting commit due to empty commit message.\n`, index 되돌림.
  5. `clock += 60`, 커밋 `{tree: index의 경로→blob, parents: [HEAD] 또는 [], message, author: "<user.name> <<user.email>>", time: clock}` 생성, 현재 브랜치 ref를 새 커밋으로.
- 출력: `[<브랜치> <h>] <메시지 첫 줄>\n` (루트면 `[<브랜치> (root-commit) <h>]`) + ` <n> file(s) changed[, <i> insertion(s)(+)][, <d> deletion(s)(-)]\n`(단수 `1 file changed`/`1 insertion(+)`/`1 deletion(-)`, 0인 항목 생략) + 경로순으로 새 파일 ` create mode 100644 <경로>\n`, 삭제 ` delete mode 100644 <경로>\n`.
- 이벤트: `Committed{hash, parents, message, branch, changedPaths}`(changedPaths 정렬).

- [ ] **Step 1: 실패하는 테스트 작성** — `test_git_diff.gd`

```gdscript
extends "res://tests/test_case.gd"

const Diff := preload("res://core/git/diff.gd")

func test_split_lines() -> void:
	assert_eq(Diff.split_lines(""), PackedStringArray())
	assert_eq(Diff.split_lines("a\n"), PackedStringArray(["a"]))
	assert_eq(Diff.split_lines("a\n\nb"), PackedStringArray(["a", "", "b"]))

func test_line_stats() -> void:
	var blue := "종류: 분수\n\n색: 파랑\n\n층수: 1\n\n장식: 꽃\n"
	assert_eq(Diff.line_stats("", blue), {"ins": 7, "del": 0})
	assert_eq(Diff.line_stats(blue, ""), {"ins": 0, "del": 7})
	assert_eq(Diff.line_stats(blue, blue.replace("파랑", "빨강")), {"ins": 1, "del": 1})
	assert_eq(Diff.line_stats("종류: 노점\n", "종류: 노점\nd\n"), {"ins": 1, "del": 0})
	assert_eq(Diff.line_stats("a\nb", "a\nb\nc"), {"ins": 1, "del": 0})
	assert_eq(Diff.line_stats("", ""), {"ins": 0, "del": 0})
```

  `commit.json` 벡터 16개:

| # | name | setup → run | expect |
|---|---|---|---|
| 1 | 루트 커밋 | init, F, `git add .` → `git commit -m "분수 추가"` | stdout `[main (root-commit) <h>] 분수 추가\n 1 file changed, 7 insertions(+)\n create mode 100644 광장/분수.txt\n`, log `["분수 추가"]`, statusShort `""`, events `["Committed"]` |
| 2 | 수정 커밋 | 1 + `@write 광장/분수.txt 색=빨강`, add → `git commit -m "분수 빨강"` | stdout `[main <h>] 분수 빨강\n 1 file changed, 1 insertion(+), 1 deletion(-)\n`, log `["분수 빨강", "분수 추가"]` |
| 3 | **add 후 재수정 → 커밋은 add 시점 내용** (명세 필수 벡터) | 1 + 빨강으로 쓰기, add, 금색으로 쓰기 → `git commit -m "분수 빨강"` | head 분수 = 빨강, index 분수 = 빨강, worktree 분수 = 금색, statusShort ` M 광장/분수.txt\n` |
| 4 | 다시 add·commit하면 최신 내용 | 3 + add → `git commit -m "분수 금색"` | head 분수 = 금색, statusShort `""`, log 3개 |
| 5 | 여러 파일·삭제 통계 | 1 + `@raw .gitignore *.log\n`, B, N, `@delete 광장/분수.txt`, `git add .` → `git commit -m "여러 변경"` | stdout `[main <h>] 여러 변경\n 4 files changed, 3 insertions(+), 7 deletions(-)\n create mode 100644 .gitignore\n create mode 100644 광장/벤치.txt\n delete mode 100644 광장/분수.txt\n create mode 100644 시장/노점.txt\n` |
| 6 | -am은 추적 파일만 | 1 + 빨강으로 쓰기, B → `git commit -am "분수 빨강"` | exit 0, head = 분수(빨강)만, statusShort `?? 광장/벤치.txt\n` |
| 7 | -a -m 분리 표기 | 6과 같은 setup → `git commit -a -m "분수 빨강"` | 6과 동일 |
| 8 | -a는 삭제도 반영 | 1 + B, add, commit, `@delete 광장/벤치.txt` → `git commit -am "벤치 철거"` | stdout `[main <h>] 벤치 철거\n 1 file changed, 1 deletion(-)\n delete mode 100644 광장/벤치.txt\n` |
| 9 | 커밋할 것 없음(깨끗) | 1 → `git commit -m x` | 1, `E_NOTHING_TO_COMMIT`, stdout `On branch main\nnothing to commit, working tree clean\n`, log `["분수 추가"]` |
| 10 | 새 파일만 있음 | 1 + B → `git commit -m x` | 1, stdout `On branch main\nUntracked files:\n  (use "git add <file>..." to include in what will be committed)\n\t광장/벤치.txt\n\nnothing added to commit but untracked files present (use "git add" to track)\n` |
| 11 | 수정만 있고 add 안 함 | 1 + 빨강으로 쓰기 → `git commit -m y` | 1, stdout `On branch main\nChanges not staged for commit:\n  (use "git add <file>..." to update what will be committed)\n  (use "git restore <file>..." to discard changes in working directory)\n\tmodified:   광장/분수.txt\n\nno changes added to commit (use "git add" and/or "git commit -a")\n` |
| 12 | unborn에서 커밋할 것 없음 | init → `git commit -m x` | 1, stdout `On branch main\n\nInitial commit\n\nnothing to commit (create/copy files and use "git add" to track)\n` |
| 13 | -m 없음 | init, F, add → `git commit` | 1, `E_NEED_MESSAGE`, 위 stderr, index 유지, log `[]` |
| 14 | 빈 메시지 | init, F, add → `git commit -m "  "` | 1, `E_EMPTY_MESSAGE`, stderr `Aborting commit due to empty commit message.\n`, log `[]` |
| 15 | -a + -m 없음은 index를 되돌림 | 1 + 빨강으로 쓰기 → `git commit -a` | 1, `E_NEED_MESSAGE`, index 분수 = 파랑 |
| 16 | 충돌 표시자가 남아도 커밋 허용 | init, Task 4의 13번 파일, add → `git commit -m "표시자"` | exit 0, log `["표시자"]` |
| 17 | 끝 개행 없는 파일·빈 파일 | init, `@raw a.txt 1\n2`, `@raw b.txt`, `git add .` → `git commit -m "raw"` | stdout `[main (root-commit) <h>] raw\n 2 files changed, 2 insertions(+)\n create mode 100644 a.txt\n create mode 100644 b.txt\n` |

  `status.json`에 추가 (9~14):

| # | name | setup → run | expect.stdout |
|---|---|---|---|
| 9 | 커밋 후 깨끗 | commit#1 setup+run → `git status` | `On branch main\nnothing to commit, working tree clean\n` |
| 10 | 수정(미스테이징)+untracked | + 빨강으로 쓰기, B, N → `git status` | commit#11의 stdout에서 untracked 섹션(`\t광장/벤치.txt\n\t시장/\n`)이 `modified` 섹션 뒤에 들어간 형태 |
| 11 | staged+unstaged 같은 파일 | + 빨강, add, 금색 → `git status` | `On branch main\nChanges to be committed:\n  (use "git restore --staged <file>..." to unstage)\n\tmodified:   광장/분수.txt\n\nChanges not staged for commit:\n  (use "git add <file>..." to update what will be committed)\n  (use "git restore <file>..." to discard changes in working directory)\n\tmodified:   광장/분수.txt\n\n` |
| 12 | 위 -s | → `git status -s` | `MM 광장/분수.txt\n` |
| 13 | 스테이징 후 삭제 | + 빨강, add, `@delete 광장/분수.txt` → `git status` | staged `modified`, unstaged 힌트가 `  (use "git add/rm <file>..." to update what will be committed)\n`, `\tdeleted:    광장/분수.txt\n` |
| 14 | 삭제 스테이징 -s | + `@delete 광장/분수.txt`, `git add .` → `git status -s` | `D  광장/분수.txt\n` |

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `VECTORS: 50`, `failed=0`
- [ ] **Step 5: 커밋** — `Git 코어: git commit과 줄 통계`

---

### Task 7: `git log`

**Files:**
- Create: `game/core/git/commands/cmd_log.gd`, `game/tests/vectors/log.json`
- Modify: `git.gd`, `messages.gd`

**Interfaces:**
- Consumes: `Repo.head_commit`, `Objects.short`.
- 동작 (명세 4.5): HEAD에서 도달 가능한 커밋을 `time` 내림차순(같으면 발견 순서)으로. 옵션 `--oneline`, `-n <N>`, `-n<N>`, `-<N>`. `--graph`·`--all`·그 외 옵션은 `E_UNSUPPORTED_OPTION`(129, Task 5와 같은 문구) — 2주차에 구현.
- 기본 형식 (커밋 사이 빈 줄 1개, 메시지 각 줄 4칸 들여쓰기):

```text
commit <H> (HEAD -> main)
Author: 플레이어 <player@versionland.example>
Date:   Mon Mar 2 09:02:00 2026 +0900

    분수 빨강

commit <H>
Author: 플레이어 <player@versionland.example>
Date:   Mon Mar 2 09:01:00 2026 +0900

    분수 추가
```

- 날짜: `Time.get_datetime_dict_from_unix_time(time + 32400)`로 계산, 형식 `<요일 3자> <월 3자> <일(채움 없음)> HH:MM:SS YYYY +0900`.
- 장식: 그 커밋을 가리키는 ref가 있을 때만 ` (…)`. 순서 `HEAD -> <현재 브랜치>`(detached면 `HEAD`), 나머지 로컬 브랜치 이름순, `remoteRefs`의 `<원격>/<브랜치>` 이름순. 쉼표+공백으로 연결.
- `--oneline`: `<h> (HEAD -> main) 분수 빨강\n` / `<h> 분수 추가\n` (메시지 첫 줄만).
- 커밋 없음: exit 128, `E_NO_COMMITS`, stderr `fatal: your current branch 'main' does not have any commits yet\n`.

- [ ] **Step 1: 벡터 작성** — `log.json` 8개: ① 커밋 2개 기본 형식(위 전체 텍스트, 끝 개행 1개) ② `--oneline` ③ `-n 1 --oneline` → 첫 줄만 ④ `-1 --oneline` ⑤ `-n1` 기본 형식 → 첫 커밋 블록만 ⑥ 빈 저장소 → 128/`E_NO_COMMITS`/위 stderr ⑦ `--graph` → 129/`E_UNSUPPORTED_OPTION` ⑧ 여러 줄 메시지: `@`가 아닌 직접 호출이 필요하므로 메시지 `"첫 줄"`만 쓰고, 대신 `-n 5`가 커밋 수보다 커도 전체 2개만 출력됨을 확인.
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `VECTORS: 58`, `failed=0`
- [ ] **Step 5: 커밋** — `Git 코어: git log (기본, --oneline, -n)`

---

### Task 8: 성능 확인 · 문서 반영 · 최종 검증

**Files:**
- Modify: `game/tests/test_git_run.gd`, `docs/GIT_SIMULATOR_SPEC.md`(3장), `docs/GODOT_ARCHITECTURE.md`(3장 ✅ 표기·9장 표), `docs/IMPLEMENTATION_PLAN.md`(P1 표 1주차 진행 표시), `README.md`("게임 프로젝트" 문단), `game/README.md`

- [ ] **Step 1: 성능 테스트 추가** (게이트 G1 "명령 1개 10ms 이내"의 1주차분)

```gdscript
func test_commands_average_under_10ms() -> void:
	var w := World.create()
	Git.run(w, "git init")
	var Repo := preload("res://core/git/repo.gd")
	var start := Time.get_ticks_usec()
	var commands := 0
	for i in 50:
		Repo.write_file(w, Repo.find(w), "광장/건물%d.txt" % i, "종류: 집\n\n층수: %d\n" % (i % 5 + 1))
		for cmd in ["git add .", "git status", "git commit -m \"건물 %d\"" % i, "git log --oneline"]:
			assert_eq(Git.run(w, cmd)["exit_code"], 0, cmd)
			commands += 1
	var avg_ms := float(Time.get_ticks_usec() - start) / 1000.0 / commands
	assert_true(avg_ms < 10.0, "평균 %.2fms" % avg_ms)
```

- [ ] **Step 2: 실행** — 실패하면 병목(대개 `Repo.worktree` 반복 계산·log 정렬)만 고친다.
- [ ] **Step 3: 문서 반영** — 명세 3장 끝에 "GDScript 구현은 `Repo.worktree`를 `World.fs`(절대 경로 → 내용)의 저장소 경로 아래 보기로 두고, `--global` 설정은 `World.config`에 둔다" 1문단 추가. 아키텍처 3장 트리에 작성된 파일 ✅, 9장 "테스트 벡터" 상태를 "1주차분 58개 작성"으로. 구현 계획서 P1 표 1주차에 "데이터 모델·init/add/commit/status/log·벡터 형식 ✅, 실제 Git 대조 도구 미착수(별도 계획)". README 두 곳의 "Git 시뮬레이터 … 미구현" 문구를 실제 상태로. **학교 검증·difftest·260개 게이트는 미달성으로 그대로 둔다.**
- [ ] **Step 4: 최종 검증** — 테스트 명령(`failed=0`, `VECTORS: 58` 이상), `$GODOT --headless --path game --quit-after 60`(오류 없음), `git diff --check`.
- [ ] **Step 5: 커밋** — `Git 코어 1주차: 성능 확인과 문서 반영`
