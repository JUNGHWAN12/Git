# ⚙️ Git 시뮬레이터 명세서 (git-core)
### 「커밋 크래프트」 엔진 독립 Git 코어 — 구현 기준 문서 v1.0

> **원칙: 시뮬레이터가 실제 Git과 다르게 동작하면 그건 버그다.**
> 학생에게 틀린 개념을 가르치는 교육용 게임은 재미없는 게임보다 나쁘다.
> 이 문서의 메시지·동작은 **실제 Git 2.43.0에서 직접 실행해 확인**한 결과를 기준으로 한다. (확인 스크립트: 부록 C)

---

## 0. 범위

| 구분 | 내용 |
|---|---|
| MVP 지원 | `init` `status` `add` `commit` `log` `show` `diff` `restore` `branch` `switch` `checkout`(별칭) `merge` `revert` `clone` `remote` `fetch` `pull` `push` `config`(일부 키) + 셸 `cd` `ls` `cat` `clear` |
| 2차 지원 | `stash` `rebase` `reset` `cherry-pick` `tag` `rm --cached` `merge --no-ff` |
| 별도 계층 (git-core 밖) | GitHub 기능: Pull Request, 리뷰, Fork, Issue, 브랜치 보호 → `hub-sim` 패키지 (8장) |
| 지원 안 함 | 서브모듈, worktree, 바이너리 파일, 심볼릭 링크, 파일 권한, hooks, 대화형 명령(`-i`), 에디터 실행 |

---

## 1. 허용되는 단순화 vs 금지되는 단순화

### 1.1 ✅ 허용 (학습 개념에 영향 없음)
| 단순화 | 이유 |
|---|---|
| 해시는 결정적 SHA-1(자체 직렬화)이며 실제 Git 해시와 값이 다르다 | 해시 값 자체는 학습 대상이 아님. 40자리·앞 7자리 표시 형식은 동일하게 유지 |
| 트리를 `경로 → 블롭해시` 평면 맵으로 저장 | 하위 트리 객체는 학습 대상이 아님 |
| 에디터를 열지 않음: `commit`은 `-m` 필수, 병합/revert는 기본 메시지 자동 사용 | 교실에서 vim 탈출 문제 방지. 단, `-m` 없는 `commit` 입력 시 "실제 Git에서는 에디터가 열려요" 안내 |
| 시간은 가상 시계 (스테이지 시작 시각 + 커밋마다 +60초) | 재현성 |
| 원격 URL은 가상 주소 `https://hub.versionland/<주인>/<섬>.git` | 실제 네트워크 없음 |
| 셸은 `cd` `ls` `cat` `clear`만 | 파일 편집은 게임 UI(마을/충돌 편집기)로 |
| 한글 경로를 따옴표·8진수 이스케이프 없이 표시 (`core.quotePath=false` 상태로 고정) | 실제 Git 기본값은 `"\352\264\221..."` 처럼 표시됨 → 에필로그 설치 가이드에서 `git config --global core.quotePath false` 를 반드시 안내 |
| 출력 언어는 영어 원문 고정 + 한국어 해설 별도 표시 | 실제 Git은 OS 언어에 따라 한국어로 나올 수도 있음 → 해설 패널에서 언급 |

### 1.2 ❌ 금지 (오개념을 만든다)
- 커밋을 "차이(diff) 목록"으로 저장하고 재생하는 구조 (커밋 = 스냅샷이어야 함)
- 브랜치 생성 시 파일·커밋 복사
- `commit`이 원격에 영향을 주는 동작
- `fetch`가 작업 디렉터리나 로컬 브랜치를 바꾸는 동작
- non-fast-forward `push` 허용 (force 제외)
- `status`의 ahead/behind를 **실시간 원격 기준**으로 계산 (실제는 마지막 fetch 기준 — 5.6 참조)
- 충돌 표시자가 남은 파일의 `add`/`commit`을 시뮬레이터가 막는 것 (실제 Git은 막지 않는다! 게임 판정·깃토리 경고로만 처리)
- 같은 줄/인접 줄 충돌 규칙을 실제와 다르게 단순화 (4.3 참조)

---

## 2. 마을 ↔ 파일 매핑 (월드 모델)

게임 화면의 마을은 **실제 텍스트 파일의 렌더링 결과**다. 렌더러는 파일을 읽어 그리기만 하고, 마을을 바꾸는 모든 조작은 파일을 바꾼다.

| 마을 | Git |
|---|---|
| 마을 전체 | 저장소 루트 디렉터리 |
| 구역 (광장, 시장, 주거지, 축제…) | 폴더 `광장/` |
| 건물 1채 | 파일 `광장/분수.txt` |
| 건물 속성 (색, 층수, 장식…) | 파일 안의 한 줄 |
| 빈 구역 | 존재하지 않음 (Git은 빈 폴더를 추적하지 않음 — 실제와 동일) |
| 투명 망토 | `.gitignore` 파일 |

### 2.1 건물 파일 형식 (고정)
```text
종류: 분수

색: 파랑

층수: 1

장식: 꽃
```
- UTF-8, 줄 끝 `\n`, 파일 끝 개행 1개.
- **속성 사이에 빈 줄 1개 필수.** 게임 UI는 항상 이 형식으로 저장한다.
- 이유 (실제 Git으로 확인함):
  - 빈 줄 없이 붙은 두 줄을 양쪽이 각각 고치면 → **충돌** (인접 변경은 한 덩어리로 취급)
  - 빈 줄로 떨어진 두 줄을 양쪽이 각각 고치면 → **자동 병합 성공**
  - → 이 형식 덕분에 "다른 속성을 고치면 자동 병합, 같은 속성을 고치면 충돌"이 **실제 Git 규칙 그대로** 성립한다.
- 파싱 실패(충돌 표시자 포함 등) 시 렌더러는 **"깨진 건물(지지직)"** 로 표시한다.

### 2.2 속성 사전 (MVP)
| 키 | 값 예시 |
|---|---|
| 종류 | 집, 분수, 우물, 가로등, 벤치, 깃발, 무대, 노점, 시계탑, 다리, 쓰레기더미 |
| 색 | 파랑, 빨강, 노랑, 초록, 금색, 검정, 흰색 |
| 층수 | 1~5 |
| 장식 | 없음, 꽃, 등불, 리본 (여러 개는 쉼표로: `꽃, 등불`) |

---

## 3. 데이터 모델 (TypeScript 기준)

```ts
type Hash = string;            // 40자리 hex. 표시는 앞 7자리
type Path = string;            // '광장/분수.txt' (구분자 '/')

interface BlobObj   { type: 'blob'; content: string }
interface CommitObj {
  type: 'commit';
  tree: Record<Path, Hash>;    // 커밋 시점 전체 스냅샷 (평면 트리)
  parents: Hash[];             // 0개(루트), 1개, 2개(병합)
  message: string;
  author: string;              // 플레이어 닉네임 / NPC 이름
  time: number;                // 가상 시계
}

type IndexEntry =
  | { kind: 'normal'; blob: Hash }
  | { kind: 'conflict'; base?: Hash; ours?: Hash; theirs?: Hash }; // stage 1/2/3

type Head =
  | { kind: 'branch'; name: string }   // 커밋이 없어도 가능 (unborn branch)
  | { kind: 'detached'; commit: Hash };

interface Repo {
  path: string;                                  // 가상 디렉터리 '/home/player/마을'
  objects: Map<Hash, BlobObj | CommitObj>;
  heads: Record<string, Hash>;                   // refs/heads/*
  remoteRefs: Record<string, Record<string, Hash>>; // refs/remotes/origin/*
  head: Head;
  index: Record<Path, IndexEntry>;
  worktree: Record<Path, string>;
  remotes: Record<string, { url: string }>;
  upstream: Record<string, { remote: string; branch: string }>;
  merge?: { theirs: Hash; label: string; message: string }; // MERGE_HEAD
  config: {
    'user.name': string;
    'pull.rebase'?: 'false' | 'true';            // 미설정이 기본 (실제와 동일)
    'init.defaultBranch': 'main';
  };
}

interface Hub {                                  // 가상 원격 서버 (허브 섬)
  repos: Record<string /* url */, BareRepo>;     // BareRepo = objects + heads (worktree/index 없음)
}

interface World {                                // 시뮬레이터 전체 상태
  cwd: string;
  repos: Record<string /* path */, Repo>;
  hub: Hub;
  clock: number;
  log: GitEvent[];                               // 이벤트 소싱 (되감기·리플레이·분석)
}
```

### 3.1 해시 계산 (결정적)
```
blobHash   = sha1("blob\0" + content)
commitHash = sha1("commit\0" + 정렬된 tree 항목 + parents + author + time + message)
```
같은 스테이지·같은 입력이면 항상 같은 해시가 나와야 한다 (리플레이·테스트 재현성).

### 3.2 불변식 (매 명령 실행 후 검사 — 개발 빌드에서는 위반 시 즉시 예외)
1. `head.kind === 'branch'` 이면 해당 브랜치는 `heads`에 있거나, **아직 커밋이 하나도 없는 상태(unborn)** 다.
2. 모든 ref가 가리키는 해시는 `objects`에 존재하는 커밋이다.
3. 모든 커밋의 부모는 `objects`에 존재한다 (순환 없음).
4. `merge`가 있으면 `index`에 conflict 항목이 있거나, 모두 해결되어 커밋 대기 중이다.
5. `fetch`는 `heads`·`worktree`·`index`를 절대 바꾸지 않는다.

---

## 4. 명령별 명세

> 표기: **출력**은 실제 Git 원문 (`<h>` = 7자리 해시, `<H>` = 40자리). 각 오류에는 게임용 **오류 코드**와 **깃토리 해설**을 붙인다.

### 4.1 `git init`
- 동작: `cwd`에 저장소 생성. `head = {branch, 'main'}`, 커밋 없음(unborn).
- 출력: `Initialized empty Git repository in <cwd>/.git/`
- 이미 저장소이면: `Reinitialized existing Git repository in <cwd>/.git/` (상태 변화 없음)

### 4.2 `git status`
비교 3종으로 계산한다.
| 섹션 | 비교 |
|---|---|
| `Changes to be committed:` | HEAD 트리 ↔ index |
| `Changes not staged for commit:` | index ↔ worktree |
| `Untracked files:` | worktree에 있고 index에 없으며 `.gitignore`에 안 걸리는 파일 (폴더 전체가 새것이면 `광장/`처럼 폴더로 표시) |
| `Unmerged paths:` | index의 conflict 항목 (`both modified:` / `both added:`) |

출력 예 (확인됨):
```text
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```
```text
On branch main
nothing to commit, working tree clean
```
upstream이 있으면 둘째 줄에 다음 중 하나 (**`remoteRefs` 기준 = 마지막 fetch 기준**):
```text
Your branch is up to date with 'origin/main'.
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish your local commits)
Your branch is behind 'origin/main' by 2 commits, and can be fast-forwarded.
  (use "git pull" to update your local branch)
Your branch and 'origin/main' have diverged,
and have 1 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)
```
병합 중이면:
```text
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
	both modified:   광장/분수.txt
```
끝줄 규칙: `nothing added to commit but untracked files present (use "git add" to track)` / `no changes added to commit (use "git add" and/or "git commit -a")` / `nothing to commit, working tree clean`.
- `-s`/`--short` 지원: `M ` ` M` `??` `UU` `A ` 형식.

### 4.3 `git add <pathspec...>` / `git add .`
- worktree 내용을 index에 기록. 삭제된 파일도 반영. conflict 항목은 normal로 바뀐다(= 해결 표시).
- `.gitignore`에 걸린 파일: `git add .`에서는 조용히 제외. 직접 지정하면 `The following paths are ignored by one of your .gitignore files:` 오류 (`E_IGNORED`).
- **충돌 표시자가 남아 있어도 add 허용** (실제와 동일). 게임은 `MarkersStaged` 이벤트를 발행 → 깃토리 경고: "Git은 막지 않아! 표시자가 남았는지는 네가 확인해야 해."
- 오류: `fatal: pathspec '<p>' did not match any files` (`E_PATHSPEC`)
- `.gitignore` 패턴 MVP 지원: 정확한 경로, `폴더/`, `*.확장자`, `#` 주석. (부정 `!`, `**` 미지원)
- 이미 추적 중인 파일은 `.gitignore`에 추가해도 계속 추적된다 (실제와 동일 → 1-6 스테이지 함정).

### 4.4 `git commit -m "<msg>"` / `-am`
- 동작: index 스냅샷으로 커밋 생성, 현재 브랜치(또는 detached HEAD)를 새 커밋으로 이동.
- `-a`: **추적 중인 파일만** 자동 add (새 파일은 안 됨 — 실제와 동일, 확인함).
- 병합 중: conflict가 없으면 부모 `[HEAD, MERGE_HEAD]` 병합 커밋 생성. `-m` 없으면 기본 메시지 `Merge branch '<label>'` 사용.
- 출력 (확인됨):
```text
[main (root-commit) <h>] 분수 추가
 1 file changed, 4 insertions(+)
 create mode 100644 광장/분수.txt
```
  - 통계 문법: `1 file changed` / `2 files changed`, `1 insertion(+)` / `3 insertions(+)`, `1 deletion(-)` / `2 deletions(-)`. 0인 항목은 생략.
- 오류
| 상황 | 출력 | 코드 |
|---|---|---|
| 스테이징 없음 + 새 파일만 있음 | (status 본문) + `nothing added to commit but untracked files present (use "git add" to track)` | `E_NOTHING_TO_COMMIT` |
| 스테이징 없음 + 수정만 있음 | `no changes added to commit (use "git add" and/or "git commit -a")` | `E_NOTHING_TO_COMMIT` |
| 변경 없음 | `nothing to commit, working tree clean` | `E_NOTHING_TO_COMMIT` |
| 미해결 충돌 | `error: Committing is not possible because you have unmerged files.` + hint + `fatal: Exiting because of an unresolved conflict.` | `E_UNMERGED` |
| `-m` 없음 | (게임 안내) "실제 Git은 여기서 에디터를 열어. 이 섬에선 `-m \"메시지\"`로 적어줘" | `E_NEED_MESSAGE` |

### 4.5 `git log` / `--oneline` / `--graph` / `--all` / `-n <N>`
- 기본 출력: `commit <H> (HEAD -> main, origin/main)` / `Author:` / `Date:` / 빈 줄 / 4칸 들여쓴 메시지.
- `--oneline`: `<h> (HEAD -> main, origin/main) 메시지`
- 장식 순서: `HEAD -> 현재브랜치`, 그 외 로컬 브랜치, `origin/*`.
- 커밋 없음: `fatal: your current branch 'main' does not have any commits yet` (`E_NO_COMMITS`)
- `--graph`: 텍스트 그래프는 실제와 **모양이 근사**해도 된다 (게임은 별도 시각 그래프가 주 화면). 단, 커밋 순서와 부모 관계는 정확해야 함.

### 4.6 `git show [<commit>]`
- 커밋 헤더 + 부모와의 diff. 병합 커밋은 헤더만 표시 (MVP 단순화).

### 4.7 `git diff` / `--staged` / `<c1> <c2>`
- `git diff`: index ↔ worktree. `--staged`(`--cached`): HEAD ↔ index. `<c1> <c2>`: 커밋 간.
- 통합 diff 형식: `diff --git a/<p> b/<p>`, `--- a/<p>`, `+++ b/<p>`, `@@ -l,s +l,s @@`, `-`/`+` 줄. 문맥 3줄.

### 4.8 `git restore <path>` / `--staged <path>` / `.`
- `restore <p>`: worktree ← index. 출력 없음.
- `restore --staged <p>`: index ← HEAD (HEAD에 없으면 index에서 제거 = 다시 untracked). 출력 없음.
- 경고 연출: 커밋 안 된 변경은 **되돌릴 수 없이 사라짐**을 깃토리가 1회 안내.

### 4.9 `git branch` 계열
| 형태 | 동작 / 출력 | 오류 |
|---|---|---|
| `git branch` | 목록, 현재 브랜치에 `* ` | — |
| `git branch <b> [<start>]` | HEAD(또는 start)를 가리키는 ref 생성. **파일·커밋 복사 없음** | 이미 존재: `fatal: a branch named '<b>' already exists` (`E_BRANCH_EXISTS`) / 커밋 없음: `fatal: not a valid object name: 'main'` (`E_NO_COMMITS`) |
| `git branch -d <b>` | HEAD(또는 그 브랜치의 upstream)에 병합된 경우만 삭제. `Deleted branch <b> (was <h>).` | 미병합: `error: the branch '<b>' is not fully merged.` + `If you are sure you want to delete it, run 'git branch -D <b>'` (`E_NOT_FULLY_MERGED`) / 현재 브랜치: `error: cannot delete branch '<b>' used by worktree at '<path>'` (`E_DELETE_CURRENT`) |
| `git branch -D <b>` | 강제 삭제 | 현재 브랜치 동일 오류 |
| `git branch -a` / `-v` | 원격 추적 브랜치 포함 / 커밋 표시 | — |

### 4.10 `git switch <b>` / `-c <b>` / `--detach <commit>`
- 출력: `Switched to branch '<b>'` / `Switched to a new branch '<b>'`
- **로컬 변경 이월 규칙 (실제 Git과 동일하게 구현할 것)**
  - 경로마다: (worktree 또는 index가 HEAD와 다름) **AND** (대상 커밋의 그 경로 내용이 HEAD와 다름) → 전환 거부
  - 그 외 변경은 **그대로 따라온다** (3-4 스테이지 학습 포인트)
  - 거부 출력 (확인됨):
```text
error: Your local changes to the following files would be overwritten by checkout:
	광장/분수.txt
Please commit your changes or stash them before you switch branches.
Aborting
```
  (`E_DIRTY_SWITCH`). untracked 파일이 덮어써질 경우: `error: The following untracked working tree files would be overwritten by checkout:` (`E_UNTRACKED_OVERWRITE`)
- 없는 브랜치: `fatal: invalid reference: <b>` (`E_INVALID_REF`)
- 커밋 해시로 전환 시도: `fatal: a branch is expected, got commit '<x>'` + `hint: If you want to detach HEAD at the commit, try again with the --detach option.` (`E_EXPECT_BRANCH`)
- 병합 중: `fatal: cannot switch branch while merging` + `Consider "git merge --quit" or "git worktree add".` (`E_MERGING`)
- `--detach`: 2차(심화) 스테이지에서 사용. 출력에 detached HEAD 안내문 포함.

### 4.11 `git checkout` (별칭 계층)
| 입력 | 변환 |
|---|---|
| `checkout <branch>` | `switch <branch>` (출력 동일: `Switched to branch '<b>'`) |
| `checkout -b <b>` | `switch -c <b>` |
| `checkout <commit>` | `switch --detach <commit>` (+ detached 안내문) |
| `checkout -- <path>` / `checkout <path>` | `restore <path>` |
- 해설 패널: "`checkout`은 기능이 많아 헷갈려서 요즘은 `switch`와 `restore`로 나눠 쓰는 걸 권장해."

### 4.12 `git merge <ref>` / `--abort`
1. `ref`를 커밋으로 해석 (브랜치, `origin/main`, 해시).
2. 대상이 HEAD의 조상 → `Already up to date.`
3. HEAD가 대상의 조상 → **Fast-forward**: 브랜치를 대상으로 이동, worktree/index 갱신.
```text
Updating <h>..<h>
Fast-forward
 b.txt | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 b.txt
```
4. 그 외 → **3-way 병합** (4.13). 충돌 없으면 병합 커밋 생성 (기본 메시지 `Merge branch '<b>'`, 대상이 원격 추적 브랜치면 `Merge remote-tracking branch 'origin/main'`):
```text
Auto-merging 광장/분수.txt
Merge made by the 'ort' strategy.
 광장/분수.txt | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```
5. 충돌 시 (확인됨):
```text
Auto-merging 광장/분수.txt
CONFLICT (content): Merge conflict in 광장/분수.txt
Automatic merge failed; fix conflicts and then commit the result.
```
   → `repo.merge` 설정, conflict 항목 기록, worktree에 표시자 기록. 병합 커밋은 아직 없음.
- 사전 조건: 병합이 건드릴 파일에 커밋 안 한 변경이 있으면 거부 (`E_DIRTY_MERGE`): `error: Your local changes to the following files would be overwritten by merge:`
- `--abort`: 병합 시작 전 상태로 index/worktree 복원, `repo.merge` 제거. 출력 없음.
- 병합 중 다시 `merge`: `fatal: You have not concluded your merge (MERGE_HEAD exists).` (`E_MERGING`)

### 4.13 3-way 병합 알고리즘
**병합 기준(merge base)**: HEAD와 대상의 최근 공통 조상(LCA).
- 공통 조상 후보가 2개 이상(criss-cross)인 경우 → `E_UNSUPPORTED_SCENARIO` 예외. **스테이지 검증기가 이런 그래프를 사전에 차단**한다.

**파일 단위 판정** (B=기준, O=우리(HEAD), T=대상)
| B | O | T | 결과 |
|---|---|---|---|
| X | X | X | 유지 |
| X | X | Y | Y 채택 |
| X | Y | X | Y 유지 |
| X | Y | Y | Y |
| X | Y | Z | **줄 단위 병합** → 충돌 가능 `CONFLICT (content)` |
| 없음 | 없음 | Y | 추가 |
| 없음 | Y | Z (Y≠Z) | 빈 기준으로 줄 단위 병합 → 보통 `CONFLICT (add/add): Merge conflict in <p>` |
| X | 삭제 | X | 삭제 |
| X | 삭제 | Y (수정) | `CONFLICT (modify/delete)` → **MVP 미지원**, 스테이지 검증기가 차단 |

**줄 단위 병합 (diff3)**
1. B→O, B→T 각각 Myers diff로 변경 덩어리(hunk) 계산.
2. 두 쪽 덩어리가 **겹치거나 맞닿아 있으면(사이에 변경 안 된 줄이 0줄)** 하나의 충돌 덩어리로 합친다 → 실제 Git과 동일 (2.1 실험 결과).
3. 양쪽이 같은 내용으로 바꿨으면 충돌 아님.
4. 충돌 표시자:
```text
<<<<<<< HEAD
색: 노랑
=======
색: 빨강
>>>>>>> <라벨>
```
   - `<라벨>` = `git merge`에 준 이름 그대로 (`feature/festival`, `origin/main`).
   - **`git pull`로 생긴 충돌은 라벨이 40자리 커밋 해시** (확인됨).
- 라이브러리(예: diff3 구현체) 사용 가능. 단, 6장 **차등 테스트를 통과해야** 한다.

### 4.14 `git revert <commit>`
- 대상 커밋과 그 부모의 차이를 반대로 현재 HEAD에 3-way 적용 (기준=대상, 우리=HEAD, 대상측=대상의 부모).
- 기본 메시지 자동 사용 (실제 `--no-edit`와 동일):
```text
Revert "가로등 철거"

This reverts commit <H>.
```
- 출력: `[main <h>] Revert "가로등 철거"` + 통계.
- 병합 커밋 revert(`-m`)는 MVP 미지원.
- 충돌 시 병합과 같은 흐름 (`git revert --abort` 지원).

### 4.15 `git clone <url> [<dir>]`
- 허브 저장소의 모든 객체 복사, `remotes.origin = url`, 허브의 모든 브랜치 → `remoteRefs.origin.*`, 허브 기본 브랜치(main)만 로컬 브랜치로 생성 + upstream 설정.
- 출력: `Cloning into '<dir>'...` / `done.`
- **cwd는 바뀌지 않는다** (실제와 동일) → `cd <dir>` 필요. 깃토리가 1회 안내.
- 없는 URL: `fatal: repository '<url>' not found` (`E_REMOTE_NOT_FOUND`)

### 4.16 `git remote` / `-v` / `add <name> <url>`
- `remote add` 출력 없음. 이미 존재: `error: remote origin already exists.` (`E_REMOTE_EXISTS`)

### 4.17 `git fetch [<remote>]`
- 허브의 새 객체 복사, `remoteRefs.origin.*` 갱신. **로컬 브랜치·index·worktree 변경 금지.**
- 출력 (확인됨):
```text
From https://hub.versionland/단비/축제마을
   <h>..<h>  main       -> origin/main
 * [new branch]      feature/x  -> origin/feature/x
```
- 새 소식 없으면 출력 없음.

### 4.18 `git push` / `push -u origin <b>` / `push origin <b>`
판정 순서:
1. 원격이 하나도 없음 → `fatal: No configured push destination.` (+ remote add 안내문) (`E_NO_REMOTE`)
2. 인자 없고 upstream 없음 → (확인됨)
```text
fatal: The current branch feat has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream origin feat
```
   (`E_NO_UPSTREAM`)
3. 허브에 그 브랜치가 없음 → 생성: ` * [new branch]      feat -> feat` (+ `-u`면 `branch 'feat' set up to track 'origin/feat'.`)
4. 허브 tip == 로컬 tip → `Everything up-to-date`
5. 허브 tip이 로컬 tip의 조상 → 갱신: `   <h>..<h>  main -> main`
6. 그 외 → **거절**. 사유는 두 가지로 나뉜다 (확인됨):
   - 허브 tip 커밋을 로컬이 **아예 모름** (fetch 안 함) → ` ! [rejected]        main -> main (fetch first)` + `hint: Updates were rejected because the remote contains work that you do not have locally...` (`E_PUSH_FETCH_FIRST`)
   - 로컬이 알지만 갈라짐 (fetch는 했음) → ` ! [rejected]        main -> main (non-fast-forward)` + `hint: Updates were rejected because the tip of your current branch is behind its remote counterpart...` (`E_PUSH_NONFF`)
   - 공통 접미: `error: failed to push some refs to '<url>'`
- 성공 시 `remoteRefs.origin.<b>`도 갱신. 첫 줄 `To <url>`.
- `--force`: MVP 비활성 (`E_DISABLED`: "이 섬에서는 다른 사람 기록을 지우는 마법이 봉인돼 있어").

### 4.19 `git pull`
= `fetch` (upstream 원격) + 결과 반영:
| 상황 | 결과 |
|---|---|
| 새 커밋 없음 | `Already up to date.` |
| fast-forward 가능 | fetch 출력 + `Updating..` / `Fast-forward` (설정 불필요) |
| **갈라짐 + `pull.rebase` 미설정** | 실제 Git 2.27+ 동작: `hint: You have divergent branches and need to specify how to reconcile them.` … `fatal: Need to specify how to reconcile divergent branches.` (`E_PULL_DIVERGENT`) — fetch는 이미 완료됨 |
| 갈라짐 + `pull.rebase=false` | 병합. 기본 메시지 `Merge branch 'main' of <url>`. 충돌 라벨은 40자리 해시 |
| 갈라짐 + `pull.rebase=true` | 2차 지원 (rebase) |

> **설계 결정**: 스테이지 5-1에서 깃토리와 함께 `git config --global pull.rebase false`를 직접 입력하게 한다. 실제 Git과 똑같이 동작하면서 학생이 첫 pull에서 막히지 않게 하고, 에필로그(실제 PC)에서도 같은 설정을 반복한다.

### 4.20 `git config [--global] <key> [<value>]`
- 지원 키: `user.name`, `user.email`, `pull.rebase`, `core.quotePath`, `init.defaultBranch`. 그 외 키는 저장만 하고 효과 없음.
- 값 없이 입력 → 현재 값 출력.

### 4.21 셸 명령
| 명령 | 지원 |
|---|---|
| `cd <dir>` / `cd ..` | 가상 경로 이동 |
| `ls` | 현재 폴더 목록 (`.git` 숨김, `ls -a`로 표시) |
| `cat <file>` | 파일 내용 (충돌 표시자 확인용) |
| `clear` | 화면 지우기 |
| 그 외 | `bash: <cmd>: command not found` + 깃토리 "이 섬에서는 Git 마법과 cd, ls, cat만 쓸 수 있어" |

### 4.22 입력 해석 공통
- 따옴표(`"`, `'`) 처리, 한글 인자 지원.
- `git` 없이 `commit -m ...` 입력 → "앞에 `git`을 붙여야 해" 힌트.
- 오타 → 실제 Git 문구 `git: 'comit' is not a git command. See 'git --help'.` + `The most similar command is` / `commit` (편집 거리 ≤ 2).
- 미지원 명령/옵션 → `E_UNSUPPORTED` + "이 섬에서는 아직 봉인된 마법이야" + 실제 의미 한 줄 설명.

---

## 5. 원격(허브 섬)과 NPC 동료

### 5.1 허브 모델
- `BareRepo`: `objects` + `heads` + `defaultBranch`. worktree·index 없음 (실제 bare 저장소와 동일).
- 허브는 플레이어 저장소와 **객체를 공유하지 않는다** (복사만). 플레이어 PC와 서버가 별개임을 구조로 보장.

### 5.2 NPC 동료 스크립트
NPC는 허브에 직접 커밋을 만드는 **가상 플레이어**다. 내부적으로 자기 로컬 저장소를 갖고 `commit`+`push`를 실행해야 한다 (허브를 직접 조작 금지 → 허브 상태가 항상 실제로 가능한 상태임을 보장).
```json
{
  "npc": "단비",
  "trigger": { "type": "afterPlayerCommand", "command": "commit", "count": 1 },
  "actions": [
    { "git": "pull" },
    { "write": "광장/분수.txt", "props": { "장식": "등불" } },
    { "git": "commit -am \"분수에 등불 달기\"" },
    { "git": "push" }
  ],
  "toast": "📢 단비가 허브 섬에 새 크리스탈을 보냈어요!"
}
```
트리거 종류: `stageStart`, `afterPlayerCommand(command, count)`, `turn(n)`, `afterEvent(eventName)`, `onWorktreeChange(path)`.
- NPC는 실제 사람처럼 **항상 `pull` 후 작업하고 push**한다. NPC의 push가 거절되거나 충돌이 나면 스테이지 설계 오류로 보고 CI 검증(STAGE_SPEC 0.5)에서 실패시킨다.

### 5.3 "착륙 거부"가 반드시 재현되는 조건
- 플레이어가 마지막 fetch 이후 NPC가 push → 플레이어 push 시 `fetch first`.
- 플레이어가 fetch 후 NPC가 또 push 하지 않았다면 → 이후 push 시 `non-fast-forward`.
- 스테이지 설계 시 원하는 메시지가 나오도록 트리거를 배치한다 (STAGE_SPEC 5-6 참조).

### 5.4 status의 ahead/behind는 "마지막으로 본 원격" 기준
- 실험 결과: 원격에 새 커밋이 있어도 fetch 전에는 `Your branch is ahead of 'origin/main' by 1 commit.` 만 표시된다.
- → 게임에서 이 상황을 **"망원경 렌즈가 오래됨"** 아이콘으로 표시하고 5-4에서 학습 포인트로 사용.

---

## 6. 이벤트 & 오류 코드

### 6.1 이벤트 (프레젠테이션·힌트·분석이 구독)
| 이벤트 | 페이로드 |
|---|---|
| `RepoInitialized` | path |
| `Staged` / `Unstaged` | paths |
| `Committed` | hash, parents, message, branch, changedPaths |
| `BranchCreated` / `BranchDeleted` | name, target |
| `HeadMoved` | from, to, carriedPaths(이월된 변경) |
| `MergeFastForward` | branch, from, to |
| `MergeCommitted` | hash, parents |
| `ConflictStarted` | paths, label |
| `MarkersStaged` | paths (표시자 남은 채 add) |
| `ConflictResolved` | path |
| `MergeAborted` | — |
| `Reverted` | target, newHash |
| `Cloned` / `Fetched` | url, updatedRefs |
| `Pushed` | branch, from, to, created |
| `PushRejected` | branch, reason: `fetch-first` \| `non-fast-forward` |
| `Pulled` | mode: `up-to-date` \| `ff` \| `merge` \| `conflict` |
| `ConfigSet` | key, value |
| `CommandError` | code, input |
| `NpcAction` | npc, summary |

### 6.2 오류 코드 → 깃토리 해설 (일부)
| 코드 | 해설 |
|---|---|
| `E_NO_COMMITS` | "아직 크리스탈이 하나도 없어. 먼저 커밋을 만들어야 이력도, 가지도 생겨!" |
| `E_NOTHING_TO_COMMIT` | "포장대가 비어 있어. `git add`로 먼저 올려야 해." |
| `E_PATHSPEC` | "그런 이름의 건물(파일)이 없어. `git status`로 이름을 확인해봐." |
| `E_DIRTY_SWITCH` | "아직 봉인 안 한 변경이 저쪽 세계와 부딪혀. 커밋하거나 되돌린 다음 이동하자." |
| `E_NOT_FULLY_MERGED` | "이 가지엔 아직 합쳐지지 않은 크리스탈이 있어. 정말 버릴 거면 `-D`야." |
| `E_UNMERGED` | "아직 지지직거리는 건물이 있어. 충돌을 고치고 `git add` 해줘." |
| `E_PUSH_FETCH_FIRST` | "허브 섬에 네가 모르는 크리스탈이 있어! 먼저 `git pull`로 받아와." |
| `E_PUSH_NONFF` | "허브 섬 기록과 네 기록이 갈라졌어. `git pull`로 합친 다음 다시 보내자." |
| `E_NO_UPSTREAM` | "이 가지는 허브 섬 어디로 갈지 몰라. 처음 한 번은 `git push -u origin <가지>`!" |
| `E_PULL_DIVERGENT` | "합치는 방식을 정해야 해. 우리 섬은 `git config --global pull.rebase false`(merge 방식)를 쓰자." |
| `E_MERGING` | "병합이 아직 진행 중이야. 끝내거나(`commit`) 취소(`merge --abort`)부터!" |

---

## 7. 테스트 명세

### 7.1 테스트 벡터 형식 (공용 JSON — 모든 엔진 포팅본이 통과해야 함)
```json
{
  "name": "push rejected: fetch first",
  "setup": [
    "@hub create 단비/마을 with 광장/분수.txt",
    "git clone https://hub.versionland/단비/마을.git",
    "cd 마을",
    "@npc 단비 write 광장/벤치.txt; commit '벤치'; push",
    "@write 광장/분수.txt 색=빨강",
    "git commit -am '분수 색'"
  ],
  "run": "git push",
  "expect": {
    "exitCode": 1,
    "errorCode": "E_PUSH_FETCH_FIRST",
    "stdoutContains": ["! [rejected]", "(fetch first)"],
    "refs": { "main": "msg:분수 색", "origin/main": "msg:base" },
    "hubRefs": { "main": "msg:벤치" }
  }
}
```
- 커밋은 해시가 아니라 `msg:<메시지>`로 참조 → 실제 Git과 비교 가능.
- `@`로 시작하는 줄은 테스트 하네스 명령 (파일 쓰기, NPC, 허브 생성).

### 7.2 차등 테스트 (실제 Git 대조) — CI 필수
1. 같은 벡터를 **실제 git**으로 실행: 임시 폴더 + bare 저장소를 허브로 사용, 환경 고정
   `LANG=C GIT_AUTHOR_NAME=… GIT_COMMITTER_DATE=…`, `-c init.defaultBranch=main -c core.quotePath=false`
2. 비교 항목 (해시 제외 정규화):
   - 각 ref → 커밋 메시지, 커밋 그래프 모양(부모 메시지 목록)
   - worktree 파일 내용 (충돌 표시자 포함, 해시 라벨은 `<H>`로 치환)
   - `git status --porcelain` 결과
   - 성공/실패, 오류 메시지 첫 줄
3. 기준 Git 버전을 고정 (현재 2.43.0)하고, 메이저 업데이트 시 재검증.

### 7.3 커버리지 목표
| 영역 | 최소 벡터 수 |
|---|---|
| init/add/commit/status | 40 |
| log/diff/show/restore | 25 |
| branch/switch/checkout (이월 규칙 포함) | 40 |
| merge (ff/3-way/충돌/abort/add-add) | 50 |
| revert | 15 |
| clone/fetch/push/pull/remote | 60 |
| 입력 파싱·오타·미지원 | 30 |
| **합계** | **260+** |

---

## 8. GitHub 계층 (hub-sim) — 2차 범위 요약
| 기능 | 모델 | 실제 동작 기준 |
|---|---|---|
| 저장소 생성 | `Hub.createRepo(owner, name, {readme?})` | README 포함 생성 시 첫 커밋 존재 → 로컬 push 시 거절됨 (함정 스테이지 소재) |
| Fork | 허브 저장소 전체 복사 → `<나>/<섬>` | 원본은 `upstream`으로 remote 추가 안내 |
| Pull Request | `{ id, base, head, title, body, state, reviews[], comments[] }`, 커밋 목록·diff는 실시간 계산 | PR 브랜치에 push하면 자동 반영 |
| 리뷰 | `comment` / `approve` / `request_changes` | |
| PR 병합 | 병합 커밋 메시지 `Merge pull request #<n> from <owner>/<branch>` | 충돌 있으면 웹 병합 불가 → 로컬에서 해결 |
| 브랜치 보호 | main 직접 push 거절: `remote: error: GH006: Protected branch update failed for refs/heads/main.` | |

---

## 부록 A. 시뮬레이터 패키지 공개 API (초안)
```ts
const world = createWorld(stage.initialState);
const result = run(world, 'git commit -m "분수 추가"');
// result: { stdout: string, stderr: string, exitCode: 0|1|128, errorCode?: string, events: GitEvent[] }
world.repo().status();          // UI용 구조화 데이터 (문자열 아님)
world.repo().graph();           // 커밋 그래프 노드/엣지 (렌더러용)
uiEditBuilding(world, '광장/분수.txt', { 색: '빨강' }); // 마을 UI 조작 → 파일 변경
snapshot(world) / restore(json) // 저장·되감기
```
- **DOM·엔진 의존 금지.** 순수 함수 + 불변 업데이트 (되감기 비용 최소화).

## 부록 B. 실제 Git과의 알려진 차이 목록 (공개 문서로 유지)
1. 해시 값이 다름 (형식은 같음)
2. 에디터 미실행 (`-m` 필수, 기본 메시지 자동)
3. 한글 경로 이스케이프 없이 표시 (`core.quotePath=false` 고정)
4. 출력 언어 영어 고정
5. `log --graph` 텍스트 모양 근사
6. criss-cross 병합, modify/delete 충돌, rename 감지 미지원 (스테이지에서 발생하지 않음)

## 부록 C. 확인 스크립트
본 문서의 출력 문구는 Git 2.43.0에서 다음 시나리오를 실행해 수집했다: 빈 저장소 log/branch/status, 루트 커밋, pathspec 오류, 브랜치 중복·삭제(현재/미병합/병합됨), 더러운 상태 전환, 커밋 해시로 switch, 인접 줄 vs 빈 줄로 떨어진 줄 병합, fast-forward, revert, bare 허브를 통한 push 거절(fetch first / non-fast-forward), fetch, ahead/diverged status, 설정 없는 갈라진 pull, pull 충돌 라벨, upstream 없는 push, 원격 없는 push, `commit -am`과 untracked, 충돌 표시자 커밋 허용, `merge --abort`, 병합 중 switch, 한글 경로 quotePath. 이 시나리오는 `tools/difftest`의 초기 테스트 벡터가 된다.
