# 🧩 MVP 스테이지 상세 명세 (프롤로그 + 챕터 1~5, 34개)
### 「커밋 크래프트」 레벨 디자인 기준 문서 v1.0

> 이 문서만 보고 스테이지 JSON을 만들 수 있어야 한다.
> 동작 규칙은 [Git 시뮬레이터 명세](GIT_SIMULATOR_SPEC.md)를 따른다. 파일 형식은 시뮬레이터 명세 2.1(속성 사이 빈 줄)을 따른다.

---

## 0. 공통 규칙

### 0.1 스테이지 카드 양식
| 필드 | 설명 |
|---|---|
| **개념** | 이 스테이지에서 새로 배우는 것 (스테이지당 새 개념 **최대 1개**) |
| **오개념** | 이 스테이지가 깨려는 착각 (사전·사후 진단 문항과 연결) |
| **초기 상태** | 커밋 그래프 / 파일 / 허브 / NPC |
| **브리핑** | 깃토리 대사 (2문장 이내) |
| **목표 판정** | 0.3 DSL로 표현. **최종 상태로만 판정** (명령 순서 무관) |
| **모범 해답** | 최소 명령. CI가 이 해답으로 자동 클리어를 검증 |
| **허용 대안** | 다른 정답 경로 (자동 테스트 1개 이상) |
| **이벤트** | NPC 행동, 함정, 연출 |
| **힌트 ①②③** | ① 질문 → ② 방향 → ③ 정답 공개 |
| **★★ 기준** | 명령 수 상한 등. ★★★ = ★★ + 힌트 미사용 + 좋은 커밋 메시지(0.4) |

### 0.2 조작 모드
- 모든 스테이지는 하이브리드(버튼 → 명령어 자동 입력)와 터미널 모드 모두 클리어 가능해야 한다.
- 건물 짓기·속성 변경·충돌 해결은 **마을 UI**로 한다 (명령 수에 포함하지 않음).

### 0.3 목표 판정 DSL
```jsonc
{ "all": [
  { "repoExists": true },
  { "head": { "branch": "main" } },                       // 또는 { "detached": true }
  { "worktreeClean": true },
  { "branchExists": "feature/festival" },
  { "branchAbsent": "feature/old" },
  { "refContains": { "ref": "main", "msgs": ["분수 추가"] } },      // 조상 포함
  { "refLacks":    { "ref": "main", "msgs": ["축제 깃발"] } },
  { "refEquals":   ["main", "origin/main", "hub:main"] },           // hub: = 허브 섬
  { "tipParents":  { "ref": "main", "count": 2 } },                 // 병합 커밋
  { "newCommits":  { "ref": "main", "min": 3, "eachTouchesOneFile": true } },
  { "fileProp":    { "at": "ref:main", "path": "광장/분수.txt", "prop": "색", "eq": "파랑" } },
  { "fileProp":    { "at": "worktree", "path": "광장/분수.txt", "prop": "장식", "includes": ["꽃","등불"] } },
  { "fileInCommit":{ "ref": "main", "path": "주거지/집.txt" } },
  { "neverCommitted": "비밀/일기.txt" },                              // 모든 커밋에서 없음
  { "noMarkers": "ref:main" },
  { "noMergeInProgress": true },
  { "upstream":    { "branch": "main", "is": "origin/main" } },
  { "config":      { "pull.rebase": "false" } },
  { "eventSeen":   "PushRejected" },                                // 체험형 목표
  { "quiz": "q-1-3" }
]}
```
- 조합자: `all`, `any`, `not`.
- 커밋은 **메시지(초기 상태의 커밋) 또는 "새 커밋 n개"** 로 지정. 플레이어 커밋 메시지는 자유이므로 메시지로 판정하지 않는다.

### 0.4 좋은 커밋 메시지 규칙 (★★★)
- 공백 제외 6자 이상
- 금지어 단독 사용 아님: `수정`, `수정함`, `ㅇㅇ`, `asdf`, `update`, `fix`, `.`, `커밋`, `ㅁㄴㅇㄹ`
- 이번 커밋에서 바뀐 건물의 **종류 또는 구역 이름**을 포함 (예: "분수 색을 파랑으로" ✅, "바꿈" ❌)

### 0.5 스테이지 자동 검증 (CI)
모든 스테이지 JSON은 CI에서 다음을 통과해야 병합할 수 있다.
1. 스키마 유효성
2. 초기 상태 불변식 (시뮬레이터 명세 3.2) + criss-cross·modify/delete가 생길 수 없는 그래프인지
3. 모범 해답 실행 → 목표 달성
4. 허용 대안 각각 실행 → 목표 달성
5. "실패해야 하는 해답" (예: 5-4에서 `git pull`) 실행 → 목표 **미달성**
6. 힌트 3단계, 오개념 태그, 브리핑 존재

### 0.6 초기 마을 (챕터 2 이후 기본값 `town-base`)
```
c1 "광장 조성"     광장/분수.txt (색: 파랑, 층수: 1, 장식: 없음)
c2 "집 두 채 짓기"  주거지/집1.txt, 주거지/집2.txt
c3 "우물 파기"     광장/우물.txt
c4 "가로등 설치"   광장/가로등.txt
c5 "벤치 놓기"     광장/벤치.txt        ← main, HEAD
```

---

## 프롤로그

### P-0. 덮어쓰기의 비극
- **개념**: 버전관리가 필요한 이유 (Git 명령 없음)
- **오개념**: "파일 이름에 _최종, _진짜최종 붙이면 충분하다"
- **진행**: 저장 개념 없는 마을에서 집을 3번 고침 → 덮어쓰기 군단이 2번째 모습을 지워버림 → 되돌릴 수 없음 체험 → 옆 마을의 `집_최종.txt`, `집_진짜최종.txt`, `집_진짜진짜최종(2).txt` 폴더를 보며 "어느 게 최신?" 퀴즈
- **목표**: 연출 완료 + 퀴즈 1문항 응답 (정답 없음, 공감 유도)
- **시간**: 3~5분

---

## 챕터 1. 첫 번째 크리스탈

### 1-1. 시간의 씨앗
- **개념**: `git init` / 저장소
- **오개념**: "Git은 프로그램을 켜면 자동으로 다 기록해준다"
- **초기 상태**: 저장소 없음, 빈 땅
- **브리핑**: "기록을 하려면 먼저 이 땅에 시간의 씨앗을 심어야 해."
- **목표**: `repoExists`
- **모범 해답**: `git init`
- **이벤트**: init 후 `git log`를 눌러보게 유도 → `fatal: your current branch 'main' does not have any commits yet` → "씨앗만 심었지 아직 기록은 없어!"
- **힌트**: ① 기록을 시작하려면 무엇부터 만들어야 할까? ② 저장소를 '처음 시작(initialize)'하는 명령이 있어 ③ `git init`
- **★★**: 명령 2개 이하

### 1-2. 첫 봉인
- **개념**: `add` → `commit` (스냅샷)
- **오개념**: "add만 하면 저장된다"
- **초기 상태**: 저장소 있음, 커밋 없음
- **브리핑**: "집을 한 채 짓고, 포장대에 올린 다음, 크리스탈에 봉인해 봐."
- **목표**: `newCommits(main, min 1)` + `fileInCommit(main, 주거지/집.txt)` + `worktreeClean`
- **모범 해답**: [UI: 집 건설] `git add 주거지/집.txt` · `git commit -m "주거지에 첫 집 짓기"`
- **허용 대안**: `git add .`
- **이벤트**: add 직후 덮어쓰기 군단 예고 연출 "포장대 위 물건은 아직 안전하지 않아!" / `git commit -am` 시도 시 실제 오류(새 파일은 -a로 안 올라감) → 힌트로 연결
- **힌트**: ① 지금 집은 4개 공간 중 어디에 있지? ② 포장대(add) → 봉인(commit) 순서야 ③ `git add 주거지/집.txt` 후 `git commit -m "메시지"`
- **★★**: 명령 2개

### 1-3. 돋보기 습관
- **개념**: `git status` 3개 섹션
- **오개념**: "지금 상태는 눈으로 보면 안다"
- **초기 상태**: 커밋 1개(집). worktree: 집 색 변경(unstaged), 새 우물(untracked), 새 벤치(staged)
- **브리핑**: "누군가 몰래 마을을 바꿔놨어. 돋보기로 무엇이 어디에 있는지 찾아내!"
- **목표**: `quiz q-1-3` (세 변경을 "봉인 대기 / 변경됨 / 새 파일" 칸에 드래그) + `git status` 1회 이상 사용(`eventSeen`)
- **모범 해답**: `git status` → 퀴즈
- **힌트**: ① 마을을 직접 보는 것보다 정확한 도구가 있어 ② 돋보기 = status ③ `git status` 출력의 세 제목을 읽어 봐
- **★★**: 퀴즈 1회에 정답

### 1-4. 골라 담기
- **개념**: 스테이징 영역의 존재 이유 (선택 커밋)
- **오개념**: "커밋은 항상 바뀐 것 전부를 저장한다"
- **초기 상태**: 커밋 1개. worktree에 새 파일 3개: `주거지/집2.txt`, `광장/우물.txt`, `광장/쓰레기더미.txt`
- **브리핑**: "의뢰는 집과 우물뿐이야. 쓰레기더미까지 기록하면 마을 역사에 영원히 남아!"
- **목표**: `newCommits(main, min 1)` + `fileInCommit(main, 집2)` + `fileInCommit(main, 우물)` + `neverCommitted(광장/쓰레기더미.txt)`
- **모범 해답**: `git add 주거지/집2.txt 광장/우물.txt` · `git commit -m "집과 우물 추가"`
- **허용 대안**: `git add .` → `git restore --staged 광장/쓰레기더미.txt` → commit / 파일을 하나씩 add
- **실패 해답(검증용)**: `git add .` → `git commit`
- **힌트**: ① 포장대에 무엇을 올릴지 고를 수 있을까? ② add 뒤에 파일 이름을 여러 개 적을 수 있어 ③ `git add 주거지/집2.txt 광장/우물.txt`
- **★★**: 명령 3개 이하

### 1-5. 좋은 이름
- **개념**: 커밋 메시지
- **오개념**: "메시지는 아무렇게나 써도 된다"
- **초기 상태**: 커밋 3개 (메시지: "수정", "ㅇㅇ", "asdf"), worktree: 분수 새로 지음
- **브리핑**: "옛 건축가의 기록이야. 무엇을 했는지 하나도 모르겠지? 너는 다르게 써 봐."
- **목표**: `quiz q-1-5` (이전 커밋 3개 중 '분수 터를 닦은 커밋' 찾기 → 불가능함을 체험, 정답 '알 수 없음') + 새 커밋 메시지가 0.4 규칙 통과
- **모범 해답**: 퀴즈 → `git add .` · `git commit -m "광장에 분수 짓기"`
- **힌트**: ① 나중의 너는 이 메시지만 보고 무엇을 알 수 있을까? ② 무엇을, 어디에 했는지 적어 ③ 예: "광장에 분수 짓기"
- **★★**: 메시지 규칙 1회 통과

### 1-6. 투명 망토
- **개념**: `.gitignore`
- **오개념**: "비밀 파일은 나중에 지우면 된다"
- **초기 상태**: 커밋 1개. worktree: `시장/가게.txt`(새), `비밀/일기.txt`(새, 비밀번호 포함)
- **브리핑**: "일기는 마을 기록에 남으면 안 돼. 한 번 커밋되면 지워도 이력에 남거든."
- **목표**: `neverCommitted(비밀/일기.txt)` + `fileInCommit(main, .gitignore)` + `fileInCommit(main, 시장/가게.txt)` + `worktreeClean`(무시된 파일 제외)
- **모범 해답**: [UI: 투명 망토 → `.gitignore`에 `비밀/`] `git add .` · `git commit -m "가게 추가, 비밀 폴더 숨기기"`
- **허용 대안**: `.gitignore`에 `비밀/일기.txt` 또는 `*.txt`가 아닌 정확한 패턴
- **이벤트(함정)**: 망토 없이 `git add .` → 일기가 포장대에 올라감 → 깃토리 경고. 이 상태로 커밋하면 **"도둑 이벤트"**: `git log`로 비밀번호가 보이는 연출 후 스테이지 재시작 (실제로는 이력 삭제가 매우 어려움을 설명)
- **힌트**: ① 기록에서 아예 빼고 싶은 것은 어떻게 표시할까? ② `.gitignore` 파일에 폴더 이름을 적어 ③ 망토 버튼 → `비밀/` 입력 → `git add .`
- **★★**: 함정에 걸리지 않음

### 1-B. 보스: 덮어쓰기 군단 1차 습격
- **개념**: 종합 (작은 단위 커밋)
- **초기 상태**: 커밋 2개. 습격까지 **행동 12턴** (명령 1개 = 1턴, UI 건설 = 1턴; 실시간 압박 없음)
- **브리핑**: "분수, 가로등, 벤치를 지어야 해. 습격 전에 봉인된 것만 살아남아. 각각 따로 봉인하면 나중에 하나만 고치기도 쉬워!"
- **목표**: `newCommits(main, min 3, eachTouchesOneFile)` + 습격 시점 `worktreeClean`
- **모범 해답**: (건설·add·commit) × 3 = 9턴
- **이벤트**: 12턴째 습격 → 커밋 안 된 변경 소멸 연출 → 그래도 커밋된 건물은 그대로임을 강조
- **힌트**: ① 습격 때 무엇이 살아남지? ② 하나 짓고 바로 봉인 ③ 건설 → add → commit 반복
- **★★**: 10턴 이내

---

## 챕터 2. 시간의 전망대 (초기 마을: `town-base`)

### 2-1. 과거 열람
- **개념**: `git log`, `--oneline`
- **오개념**: "커밋은 마지막 것 하나만 남는다"
- **목표**: `quiz q-2-1` ("우물을 판 커밋의 앞 7자리는?" 4지선다, 해시는 세션마다 다름)
- **모범 해답**: `git log --oneline`
- **힌트**: ① 전망대에 올라가 봐 ② `git log` ③ `git log --oneline`으로 한 줄씩 보기
- **★★**: 오답 0회

### 2-2. 비교 렌즈
- **개념**: `git diff`, `git diff --staged`
- **오개념**: "바뀐 건 파일 이름만 알면 된다"
- **초기 상태**: `town-base` + 분수 색 파랑→빨강(unstaged), 가로등 층수 1→3(staged)
- **목표**: `quiz q-2-2` (① 포장대에 오른 변경은? ② 그 내용은?)
- **모범 해답**: `git diff` · `git diff --staged`
- **힌트**: ① 렌즈는 두 종류야 ② 작업장↔포장대, 포장대↔크리스탈 ③ `git diff --staged`
- **★★**: 오답 0회

### 2-3. 실수 지우개
- **개념**: `git restore`, `git restore --staged`
- **오개념**: "되돌리려면 파일을 손으로 다시 고쳐야 한다"
- **초기 상태**: `town-base` + 분수 색→검정(unstaged), `주거지/집1.txt` 삭제됨(unstaged), `광장/낙서.txt`(staged)
- **브리핑**: "장난꾸러기가 마을을 엉망으로 만들었어. 마지막 크리스탈 모습으로 돌려놓자."
- **목표**: `fileProp(worktree, 분수, 색, 파랑)` + 집1 존재 + `낙서`가 index에 없음 + 새 커밋 0개
- **모범 해답**: `git restore 광장/분수.txt 주거지/집1.txt` · `git restore --staged 광장/낙서.txt`
- **허용 대안**: `git restore .` + `git restore --staged .` (순서 무관, 낙서는 untracked로 남아도 통과)
- **이벤트**: 첫 restore 시 "커밋 안 한 변경은 이렇게 사라지면 다시 못 찾아" 1회 경고
- **★★**: 명령 3개 이하

### 2-4. 반대 주문
- **개념**: `git revert`
- **오개념**: "되돌리기 = 기록 지우기"
- **초기 상태**: `town-base` + c6 "가로등 철거" (가로등 삭제) ← main
- **브리핑**: "가로등을 없앤 건 실수였어. 기록은 지우지 말고 '반대 주문'을 새로 걸자."
- **목표**: 가로등 존재(ref:main) + `refContains(main, ["가로등 철거"])` (원래 커밋 보존) + `newCommits(main, 1)`
- **모범 해답**: `git revert HEAD`
- **허용 대안**: `git revert <c6 해시>`
- **힌트**: ① 이력을 지우면 친구들의 기록과 어긋나 ② 반대 내용의 새 커밋을 만드는 명령 ③ `git revert HEAD`
- **★★**: 명령 2개 이하

### 2-B. 보스: 범인 찾기
- **개념**: 종합 (log + show/diff + revert)
- **초기 상태**: `town-base` 뒤로 커밋 6개 추가. 그중 "광장 손보기"(c8) 한 커밋만 분수 색을 검정으로 바꿈. 다른 커밋 메시지는 일부 모호. 이후 커밋들은 분수를 건드리지 않음
- **브리핑**: "분수가 검게 변했어! 어느 크리스탈이 범인인지 찾아 그것만 되돌려."
- **목표**: `fileProp(ref:main, 분수, 색, 파랑)` + 다른 커밋의 변경 전부 유지 + `refContains(main, ["광장 손보기"])`
- **모범 해답**: `git log --oneline` · `git show <c8>` · `git revert <c8>`
- **허용 대안**: `git diff <a> <b>`로 찾기
- **실패 해답**: 최신 커밋부터 연속 revert (다른 변경 소실 → 실패)
- **★★**: 명령 6개 이하

---

## 챕터 3. 평행 세계 (초기 마을: `town-base`)

### 3-1. 이름표의 비밀
- **개념**: `git branch` = 커밋을 가리키는 이름표
- **오개념**: "브랜치를 만들면 파일이 복사된다"
- **목표**: `branchExists(feature/festival)` + festival == main + `head(main)` + `quiz q-3-1` ("파일이 몇 개 복사됐을까?" 정답: 0개)
- **모범 해답**: `git branch feature/festival`
- **연출**: 이름표가 c5 열매에 '톡' 붙음. 저장 용량 게이지 변화 없음. 마을 화면 변화 없음
- **힌트**: ① 새 가지 이름표를 다는 명령 ② branch ③ `git branch feature/festival`
- **★★**: 명령 1개

### 3-2. 포털 이동
- **개념**: `git switch`, HEAD
- **오개념**: "브랜치를 만들면 자동으로 그쪽으로 이동한다"
- **초기 상태**: `town-base` + `feature/festival` (main과 같은 위치)
- **목표**: `eventSeen(HeadMoved→feature/festival)` 후 `head(main)`
- **모범 해답**: `git switch feature/festival` · `git switch main`
- **허용 대안**: `checkout` (해설 패널에 switch 권장 안내)
- **연출**: HEAD 깃발 요정이 이름표를 따라 날아감
- **★★**: 명령 2개

### 3-3. 두 세계 동시 건설
- **개념**: 갈라지는 이력
- **오개념**: "다른 브랜치에서 한 작업도 지금 마을에 보인다"
- **초기 상태**: 3-2와 동일
- **목표**: `refContains(festival, 새 커밋 ⊃ 축제/깃발.txt)` + `refLacks(main, 그 커밋)` + main에 `광장/화단.txt` 새 커밋 + festival엔 화단 없음
- **모범 해답**: `git switch feature/festival` · [깃발] · `git add .` · `git commit -m "축제 깃발 달기"` · `git switch main` · [화단] · `git add .` · `git commit -m "광장에 화단 만들기"`
- **연출**: main으로 돌아오면 **깃발이 사라짐** → 깃토리 "없어진 게 아니라 다른 세계에 있어"
- **★★**: 명령 6개 (UI 제외)

### 3-4. 포털 경고
- **개념**: 커밋 안 한 변경과 브랜치 전환 (거부 / 이월)
- **오개념**: "브랜치를 옮기면 커밋 안 한 변경은 무조건 사라진다(또는 무조건 막힌다)"
- **초기 상태**: main, festival 갈라짐. festival은 분수 색=금색으로 커밋됨. worktree(main): 분수 색=빨강(unstaged), 벤치 장식=꽃(unstaged, 벤치는 두 브랜치에서 동일)
- **브리핑**: "축제 세계로 가야 해. 그런데 포털이 이상해…"
- **목표**: `head(feature/festival)` + `fileProp(ref:main, 분수, 색, 빨강)` + `fileProp(worktree, 벤치, 장식, 꽃)` + `quiz q-3-4` ("벤치 변경은 어디로 갔나?" 정답: 따라왔다)
- **모범 해답**: `git switch feature/festival`(거부, 분수만 표시됨) · `git add 광장/분수.txt` · `git commit -m "분수를 빨강으로"` · `git switch feature/festival`
- **학습 포인트**: 오류 목록에 **분수만** 나오고 벤치는 없음 → 겹치지 않는 변경은 따라온다 (실제 Git 규칙)
- **힌트**: ① 오류에 적힌 파일은 몇 개야? ② 그 파일만 먼저 봉인하자 ③ 분수 add → commit → switch
- **★★**: 명령 4개 이하

### 3-5. 가지 정리
- **개념**: `branch -d` / `-D`
- **오개념**: "브랜치를 지우면 작업이 다 사라진다" / "-d와 -D는 같다"
- **초기 상태**: `feature/old` (main에 병합됨), `feature/test` (미병합, 실패한 실험)
- **목표**: `branchAbsent(feature/old)` + `branchAbsent(feature/test)` + `quiz q-3-5` (old의 커밋은 아직 main에 있나? 정답: 있다)
- **모범 해답**: `git branch -d feature/old` · `git branch -d feature/test`(거부) · `git branch -D feature/test`
- **★★**: `-D`를 `-d` 거부 확인 후에만 사용 (처음부터 -D는 ★)

### 3-B. 보스: 축제 준비
- **개념**: 종합
- **목표**: `feature/festival`(무대, 깃발 2커밋+), `feature/market`(노점 2커밋+) 존재, 서로의 건물 없음, main 변화 없음, `head(main)`, `worktreeClean`
- **모범 해답**: `switch -c` × 2, 커밋 4개, `switch main` (약 11개)
- **허용 대안**: `branch` + `switch`
- **★★**: 명령 12개 이하

---

## 챕터 4. 세계의 합류

### 4-1. 미끄러지는 이름표
- **개념**: Fast-forward 병합
- **오개념**: "병합하면 항상 새 커밋이 생긴다"
- **초기 상태**: `town-base` + festival이 main보다 2커밋 앞 (main은 그대로)
- **목표**: `refEquals(main, feature/festival)` + `head(main)`
- **모범 해답**: `git merge feature/festival`
- **연출**: main 이름표가 가지를 따라 **미끄러짐**. 출력의 `Fast-forward` 강조
- **★★**: 명령 1개 + 병합 커밋 없음

### 4-2. 두 부모의 크리스탈
- **개념**: 3-way 병합, 병합 커밋
- **초기 상태**: main(화단 추가), festival(깃발 추가) 갈라짐, **서로 다른 파일**
- **목표**: `tipParents(main, 2)` + main에 화단·깃발 모두
- **모범 해답**: `git merge feature/festival` (기본 메시지 자동)
- **연출**: 두 가지가 만나 큰 크리스탈. 깃토리 "부모가 둘인 크리스탈이야"
- **★★**: 명령 1개

### 4-3. 지지직!
- **개념**: 병합 충돌 (비주얼 해결)
- **오개념**: "충돌 = 고장"
- **초기 상태**: main 분수 색=노랑, festival 분수 색=금색 (같은 속성)
- **목표**: `tipParents(main, 2)` + `fileProp(ref:main, 분수, 색, ∈{노랑, 금색})` + `noMarkers(ref:main)`
- **모범 해답**: `git merge feature/festival` → [충돌 편집기: 하나 선택] → `git add 광장/분수.txt` → `git commit -m "분수 색 충돌 해결: 금색"`
- **연출**: 분수가 지지직거리며 두 모습이 겹침. 편집기는 "내 것 / 저쪽 것 / 직접" 버튼
- **★★**: 명령 3개

### 4-4. 충돌 표시 읽기
- **개념**: 충돌 표시자 `<<<<<<<` `=======` `>>>>>>>`
- **초기 상태**: 4-3과 같은 구조, 다른 건물(가로등 층수)
- **진행**: 충돌 편집기가 **텍스트 모드**로만 열림 → 학생이 표시자 줄을 직접 지움
- **목표**: 4-3과 동일 + `noMarkers`
- **이벤트(함정)**: 표시자를 남긴 채 `git add` → 실제 Git처럼 **허용됨** → 깃토리 "Git은 막아주지 않아!" → 커밋하면 깨진 건물이 크리스탈에 봉인되는 연출 후 재시도
- **힌트**: ① `<<<<<<<`부터 `>>>>>>>`까지가 한 덩어리야 ② 남길 줄만 두고 표시자 세 줄은 지워 ③ `cat`으로 확인 후 add
- **★★**: 함정에 안 걸림

### 4-5. 둘 다 살리기
- **개념**: 자동 병합되는 부분 vs 충돌 부분, 두 변경 합치기
- **오개념**: "한 파일을 둘이 고치면 무조건 충돌"
- **초기 상태**: 분수 파일 — main: 색=빨강, 장식=꽃 / festival: 층수=2, 장식=등불 (색·층수는 다른 속성, 장식은 같은 속성)
- **목표**: `fileProp(ref:main, 분수, 색, 빨강)` + `층수=2` + `장식 includes [꽃, 등불]` + `tipParents 2` + `noMarkers`
- **모범 해답**: merge → [장식: 직접 입력 "꽃, 등불"] → add → commit
- **학습 포인트**: 충돌 표시자는 **장식 줄에만** 생김 (속성 사이 빈 줄 덕분 — 실제 Git 규칙)
- **★★**: 명령 3개

### 4-6. 병합 취소
- **개념**: `git merge --abort`, 병합 중 상태
- **초기 상태**: 잘못된 브랜치(`feature/prank`)를 병합해 충돌 3개 진행 중
- **브리핑**: "앗, 장난 브랜치를 합쳐버렸어! 없던 일로 하자."
- **목표**: `noMergeInProgress` + main tip 불변 + `worktreeClean`
- **모범 해답**: `git merge --abort`
- **이벤트**: `git switch` 시도 시 `fatal: cannot switch branch while merging` 체험 유도
- **★★**: 명령 2개 이하

### 4-B. 보스: 대합류
- **개념**: 종합
- **초기 상태**: main + `feature/festival`(무대, 분수 색=금색, 가로등 장식=리본) + `feature/market`(노점, 분수 색=초록) + `feature/lights`(가로등 장식=등불). 세 브랜치 모두 main의 같은 커밋에서 출발
- **브리핑**: "축제 날이야! 세 세계를 main에 합쳐. 축제위원회 결정: 분수는 **금색**, 가로등 장식은 **등불**!"
- **목표**: main이 세 브랜치 tip 모두 포함 + `fileProp(분수, 색, 금색)` + `fileProp(가로등, 장식, 등불)` + `noMarkers` + 세 브랜치 삭제 + `worktreeClean`
- **모범 해답**: merge festival(ff) → merge market(충돌 ① 분수 색 → 금색) → merge lights(충돌 ② 가로등 장식 → 등불) → `branch -d` × 3
- **허용 대안**: 병합 순서 자유 (어떤 순서든 충돌 2건 발생, 최종 상태로 판정)
- **★★**: 명령 10개 이하

---

## 챕터 5. 하늘의 허브 섬 (NPC 동료: 단비)

> 허브 주소: `https://hub.versionland/단비/축제마을.git`
> 5-2 이후 모든 스테이지 초기 상태에는 전역 설정 `pull.rebase=false`가 포함된다 (5-1에서 학생이 직접 설정한 값과 동일. 스테이지를 건너뛰어도 동작 보장).

### 5-1. 허브 섬 발견
- **개념**: Git ≠ GitHub, 원격 저장소 / 섬 설정
- **오개념**: "Git과 GitHub는 같은 것"
- **진행**: 깃토리 설명 → 퀴즈 → 섬 설정 의식 (`git config --global pull.rebase false` 직접 입력, "pull할 때 merge로 합치겠다는 약속" 한 줄 설명)
- **목표**: `quiz q-5-1` + `config(pull.rebase=false)`
- **★★**: 퀴즈 오답 0

### 5-2. 섬 복제
- **개념**: `git clone`
- **오개념**: "clone은 최신 파일만 내려받는다"
- **초기 상태**: 허브에 커밋 5개, cwd = `/home/player`
- **목표**: 로컬 저장소 존재 + `refEquals(main, origin/main, hub:main)` + `upstream(main, origin/main)` + `eventSeen(log 실행)`
- **모범 해답**: `git clone <url>` · `cd 축제마을` · `git log --oneline`
- **이벤트**: clone 직후 `git status` → `fatal: not a git repository` → "아직 섬 밖이야! `cd`로 들어가자"
- **★★**: 명령 3개

### 5-3. 비행선 출발
- **개념**: `git push`
- **오개념**: **"커밋하면 GitHub에 올라간다"** (핵심 오개념)
- **초기 상태**: 클론 완료
- **진행**: 시계탑 건설 → add → commit → **퀴즈 "지금 단비가 허브 섬에서 시계탑을 볼 수 있을까?"** (정답: 아니오) → 허브 섬 화면 확인 → push
- **목표**: `refContains(hub:main, 새 커밋)` + `refEquals(main, origin/main, hub:main)` + `quiz q-5-3`
- **모범 해답**: `git add .` · `git commit -m "광장에 시계탑 세우기"` · `git push`
- **★★**: 명령 3개

### 5-4. 망원경과 우편함
- **개념**: `git fetch`, 원격 추적 브랜치 `origin/main`
- **오개념**: "fetch하면 내 파일이 바뀐다"
- **이벤트**: 스테이지 시작 시 단비가 커밋 2개 push ("다리 놓기", "다리 난간")
- **진행**: `git status` → "up to date"라고 나옴(마지막 fetch 기준!) → 깃토리 "망원경 렌즈가 오래됐어" → fetch → 다시 status → `behind by 2`
- **목표**: `refEquals(origin/main, hub:main)` + main 불변 + 마을에 다리 없음 + `quiz q-5-4`
- **실패 해답(검증용)**: `git pull` (main이 바뀌어 목표 미달 → "받아만 와서 우편함에 둬야 해")
- **★★**: 명령 3개 이하

### 5-5. 우편함 열기
- **개념**: `git pull` = `fetch` + `merge`
- **오개념**: "pull과 fetch는 같다"
- **진행 A**: 5-4 이어서 `git merge origin/main` → 다리가 마을에 나타남 (ff)
- **이벤트**: A 완료 후 단비가 "다리 조명" push
- **진행 B**: `git pull` 한 번에 → UI가 fetch 단계와 merge 단계를 **슬로모션으로 분리 표시**
- **목표**: `eventSeen(MergeFastForward from origin/main)` + `eventSeen(Pulled)` + `refEquals(main, hub:main)`
- **★★**: 명령 2개

### 5-6. 착륙 거부!
- **개념**: push 거절과 해결 (fetch first / non-fast-forward)
- **오개념**: "push는 항상 성공한다" / "거절되면 강제로 밀면 된다"
- **초기 상태**: 클론 완료. 플레이어가 첫 커밋을 하면 **트리거**: 단비가 다른 파일(`광장/가로등.txt`) 커밋 후 push
- **진행**: 벤치 장식 변경 → commit → push → `! [rejected] (fetch first)` → pull(병합, 충돌 없음) → push 성공
- **목표**: `eventSeen(PushRejected)` + `refContains(hub:main, [플레이어 커밋, 단비 커밋])` + `refEquals(main, hub:main)`
- **★★★ 추가 미션**: 재도전 시 이번엔 `fetch` → `status`(diverged 확인) → `push` 해서 `(non-fast-forward)` 메시지도 확인 → 두 메시지 차이 퀴즈
- **힌트**: ① 허브 섬에 네가 모르는 게 생겼대 ② 먼저 받아와서 합치자 ③ `git pull` 후 `git push`
- **★★**: `--force` 시도 없음, 명령 5개 이하

### 5-7. 연결선
- **개념**: `git remote add`, `git push -u`
- **오개념**: "init한 저장소는 자동으로 GitHub와 연결된다"
- **초기 상태**: 로컬에서 `init`으로 만든 저장소(커밋 2개, remote 없음). 허브에는 **빈** 저장소 `플레이어/내마을`이 생성되어 있음 (README 없음)
- **진행**: `git push` → `fatal: No configured push destination.` → remote add → `git push` → `no upstream branch` → `git push -u origin main`
- **목표**: `refEquals(main, hub:main)` + `upstream(main, origin/main)`
- **★★**: 명령 2개 (`remote add` + `push -u`)

### 5-B. 보스: 두 섬의 경주
- **개념**: 종합 (원격 협업 + 충돌)
- **초기 상태**: 클론 완료. 미션 3개: 분수 장식에 "꽃" 추가, 시장 노점 1개, 주거지 집3
- **NPC 트리거** (NPC는 항상 `pull → 수정 → commit → push` 순서로 행동)
  ① 플레이어 첫 커밋 직후: 단비가 가로등 장식 변경 push
  ② 플레이어가 **분수 파일을 처음 수정하는 순간**(worktree 변경 이벤트): 단비가 분수 장식=등불 push
  → 플레이어가 분수를 커밋·push하면 반드시 거절 → pull 시 장식 줄 충돌 (미션 순서와 상관없이 재현됨)
- **브리핑**: "단비와 동시에 축제 마을을 완성하자. 분수 장식은 꽃과 등불 **둘 다**!"
- **목표**: 허브 main이 플레이어 커밋 3개 이상 + 단비 커밋 2개 포함 + `fileProp(hub:main, 분수, 장식, includes[꽃, 등불])` + `noMarkers(hub:main)` + `refEquals(main, hub:main)` + `worktreeClean`
- **충돌 라벨**: pull 충돌이므로 `>>>>>>> <40자리 해시>` (실제와 동일) → 깃토리 "이 긴 문자열은 단비 커밋의 이름이야"
- **★★**: 명령 16개 이하, force 없음

---

## 부록 A. 진단 문항 ↔ 스테이지 연결
| 진단 문항 (GDD 18.4) | 오개념 | 핵심 스테이지 |
|---|---|---|
| 1. 커밋 직후 친구가 볼 수 있다 | commit = upload | 5-3 |
| 2. 브랜치 = 파일 복사 | branch = copy | 3-1 |
| 3. pull = fetch + ( ) | pull = fetch | 5-4, 5-5 |
| 4. 병합 커밋 고르기 | 그래프 읽기 | 4-2 |
| 5. push 거절 시 할 일 | push 항상 성공 | 5-6 |
| 6. 공유 커밋 되돌리기 | revert = 삭제 | 2-4 |

## 부록 B. 스테이지별 예상 소요 시간 (플레이테스트로 보정)
| 챕터 | 스테이지 수 | 예상 시간 |
|---|---|---|
| 프롤로그 | 1 | 5분 |
| 1 | 7 | 35분 |
| 2 | 5 | 30분 |
| 3 | 6 | 35분 |
| 4 | 7 | 45분 |
| 5 | 8 | 55분 |
| **합계** | **34** | **약 3시간 25분 (4차시 내외)** |
