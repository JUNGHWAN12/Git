# 커밋 크래프트: 시간의 나무 (Commit Craft)

고등학생에게 Git·GitHub 버전관리 개념(커밋, 브랜치, 병합, push/pull/fetch, Pull Request 등)을 가르치기 위한 교육용 게임 저장소입니다.

**실행 환경: Windows PC (학교 컴퓨터실) · 엔진: Godot 4.7.2 + GDScript**

## 문서
| 문서 | 내용 |
|---|---|
| 📄 [게임 기획서 (GDD)](docs/GAME_DESIGN_DOCUMENT.md) | 무엇을, 왜 — 콘셉트, 개념↔메커닉 매핑, 챕터 구성, UI, 운영 시나리오 |
| 🟩 [Godot 아키텍처](docs/GODOT_ARCHITECTURE.md) | 어떻게 — 계층 구조, 폴더, 노드 구성, 한글 처리, 내보내기, 테스트 |
| ⚙️ [Git 시뮬레이터 명세](docs/GIT_SIMULATOR_SPEC.md) | 어떤 규칙으로 — 명령별 동작·출력·오류 (실제 Git 2.43으로 확인) |
| 🧩 [MVP 스테이지 명세](docs/STAGE_SPEC_MVP.md) | 어떤 퍼즐을 — 34개 스테이지의 초기 상태·판정·힌트 |
| 🛠️ [구현 계획서](docs/IMPLEMENTATION_PLAN.md) | 언제, 어떤 순서로 — 단계별 게이트, 범위 고정, 완료 정의 |
| 🪟 [Windows 실행 환경](docs/WINDOWS_ENVIRONMENT.md) | 어디서 — 학교 Windows PC 대응, 실제 Git for Windows 설치·설정 |
| 🎮 [엔진별 비교](docs/ENGINE_COMPARISON.md) | 엔진 결정 전 비교 기록 |

문서끼리 내용이 다르면 **시뮬레이터 명세 > 스테이지 명세 > 게임 기획서** 순으로 따릅니다.

## 게임 프로젝트
[`game/`](game/) — Godot 4.7.2 프로젝트. 지금은 **P0 기술 스파이크**(한글 입력·터미널·커밋 그래프 시험 화면)와 첫 핵심 로직(건물 파일 형식, 한/영 전환 감지), 헤드리스 테스트가 들어 있습니다. Windows에서 여는 법은 [`game/README.md`](game/README.md).
