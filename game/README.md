# 커밋 크래프트 — Godot 프로젝트

설계 기준: [Godot 아키텍처](../docs/GODOT_ARCHITECTURE.md)

## Windows PC에서 열기
1. [godotengine.org](https://godotengine.org/download/windows/)에서 **Godot 4.7.2 (표준판, .NET 아님)** 를 내려받아 압축을 푼다. 설치는 필요 없다.
2. `Godot_v4.7.2-stable_win64.exe` 실행 → **가져오기(Import)** → 이 폴더의 `project.godot` 선택.
3. **F5** 를 누르면 P0 기술 스파이크 화면이 뜬다.

## P0 스파이크 체크리스트 (학교 컴퓨터실 PC에서)
| 탭 | 확인 | 결과 |
|---|---|---|
| ① 한글 입력 | '광장에 분수 짓기' 입력 후 Enter → 기록에 끝 글자 중복 없음 | ☐ |
| ① 한글 입력 | 여러 줄 칸에서 한글 입력·수정 정상 | ☐ |
| ② 터미널 | 한글 상태로 `git status` → 한/영 안내 문구가 뜸 | ☐ |
| ② 터미널 | ↑↓ 로 이전 명령 불러오기 | ☐ |
| ③ 커밋 그래프 | 커밋 100개, 부하 시험 켜고 FPS 30 이상 | ☐ |
| ④ 교실 네트워크 | 선생님 PC에서 [서버 열기] (방화벽 창이 뜨면 결과 기록) | ☐ |
| ④ 교실 네트워크 | 학생 PC 3대 이상이 선생님 PC 주소로 [접속] → 명단에 모두 보임 | ☐ |
| ④ 교실 네트워크 | 한 학생의 [알림 보내기]가 다른 학생 화면에 뜸 | ☐ |
| 공통 | 창 크기 1366×768에서 잘림 없음 | ☐ |

## 테스트 실행
```bash
# Godot 실행 파일 경로를 맞춰서
godot --headless --path game --script res://tests/run_tests.gd
```
마지막 줄 `RESULT: passed=N failed=0` 이면 통과. GitHub에 올리면 Actions가 같은 테스트를 자동으로 돌린다.

## 폴더
| 폴더 | 내용 |
|---|---|
| `core/` | 엔진 기능을 쓰지 않는 순수 로직 (Git 시뮬레이터, 건물 파일, 한/영 감지) |
| `core/net/` | 교실 협업 통신 (서버·접속·규약) |
| `scenes/spike/` | P0 기술 스파이크 (검증 후 삭제) |
| `tests/` | 헤드리스 테스트 |
