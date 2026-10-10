# 디자인 산출물 인계 — RetireX Online 세션이 준비한 것

2026-10-10 · RetireX Online 개발 세션이 운영자(디자이너)의 요청으로 만들었다. **아직 커밋하지 않았다.** 디자이너가 확인한 뒤 `design` 브랜치에 올린다.

결정 20·21(같은 날 커밋 `75ec00f`)을 반영했다. 팔레트는 RetireX 색 체계를 쓰고, 마인크래프트 텍스처는 쓰지 않는다. 카트는 5종이다.

## 1. 디자인 PRD 15장 체크리스트 대응

| PRD 항목 | 상태 | 파일 |
| --- | --- | --- |
| `Design/style-guide.md` | 완료(결정 20-11 반영: RetireX 색 체계) | `Design/style-guide.md`, `Design/palette.png` |
| `kart_01` | 대체됨(결정 14·20-7). 대신 카트 5종 그림을 만듦 | `Design/karts/kart_<id>_thumb.png`(메뉴 카드), `kart_<id>_silhouette.svg`(작은 표시) |
| 타일 4종 + `tiles.png` + 2×2 미리보기 | 완료 | `Assets/blockbench/tiles/*.bbmodel`, `tiles.png`, `Assets/export/glb/*.glb`, `Design/reference/tiles_preview.png`, `tiles_preview_track01.png` |
| 아이콘 세트 SVG, 온보딩 그림 4장 | 완료 | `Design/icons/icon_*.svg`, `Design/onboarding/gesture_0*.svg`(각 `_sheet.png` 미리보기) |
| 미니맵 깃발·라벨 아이콘, `minimap.png` 목업 | 완료 | `Design/icons/icon_minimap_*.svg`, `Design/mockups/minimap.png` |
| 화면 목업 7장 | 완료 | `Design/mockups/01_start` ~ `07_result` (`.png` + `.svg`) |
| 효과음 7개 + `LICENSES.md` | 완료(직접 합성, 외부 소재 없음) | `Assets/sfx/*.wav`, `Assets/sfx/LICENSES.md` |
| 픽셀 폰트 파일 + 라이선스 확인 | **파일 받기 남음**: Galmuri, SIL OFL 1.1 확인함 | `Design/fonts/README.md`(받는 곳·넣는 법·OFL 요점) |
| 앱 이름 확정 → `Docs/decisions.md` 7번 | 후보 3개 제안(결정은 보류 상태 그대로) | `Design/proposals/app-name.md` |

추가로 만든 것:

- **대체 텍스처 15장**(결정 21): `Design/textures/tex_*.png`, 16 × 16. RetireX 트랙 재료의 99 %를 덮는다(대응표: `Design/reference/retirex/textures/TEXTURES.md` 3장).
- **RetireX 참고 자료 묶음**: `Design/reference/retirex/` — 트랙 5종(도면·미니맵·코스 데이터·렌더), 미니맵 동작 전부, 렌더링 방법, 트랙 제작 노하우, 라이선스 경계. 시작은 그 폴더의 `README.md`다.

## 2. 결정 20 반영 내역

| 결정 | 반영 |
| --- | --- |
| 20-1 카트 그림 | 메뉴 카드는 RetireX 차고 렌더(3D) 썸네일이다. 작은 표시에는 카트 모델 형상에서 뽑은 24 px 옆모습 실루엣을 쓴다 |
| 20-2 색상 스와치 | 원 28 pt, 간격 10 pt, 색상환 순서, 선택 링과 색 이름 — 스타일 가이드 1-3 |
| 20-3 타이포 | 제목에만 픽셀 폰트를 쓴다 — 스타일 가이드 2장 |
| 20-4 글래스 유지 | 목업의 카드·버튼 바탕은 글래스 그대로 두고, RetireX 색은 강조에만 썼다 |
| 20-7·20-8 카트 5종 | `mms`는 그림을 만들지 않았다 |
| 20-11 팔레트 | 트랙·UI·카트 도색 17색·미니맵 색을 RetireX에서 뽑았다. 타일·아이콘·목업을 다시 칠했다 |
| 20-12·20-13 RetireX 리소스 | 카트 썸네일은 RetireX 그림을 PRD식 이름(`kart_<id>_thumb.png`)으로 바꿔 넣었다 |
| 21 바닐라 금지 | 참고 문서의 "임시로 빌려 쓰기" 절차를 지웠다(복사 스크립트 삭제). 대신 대체 텍스처를 그렸다 |

## 3. 다시 만들기

모든 산출물은 코드로 만들었다. 숫자나 색을 바꾸면 아래 명령으로 다시 만든다(Node 20 이상).

| 명령 | 만드는 것 | 필요한 것 |
| --- | --- | --- |
| `node Design/tools/palette.mjs` | `Design/palette.png` | sharp |
| `node Design/tools/tiles.mjs` | 타일 `.bbmodel`·`tiles.png`·`.glb`, 미리보기 2장 | 없음 |
| `node Design/tools/icons.mjs` | 아이콘·온보딩 SVG와 미리보기 | sharp(미리보기만) |
| `node Design/tools/mockups.mjs` | 목업 8장(타일·아이콘 먼저 만들 것) | sharp |
| `node Design/tools/sfx.mjs` | 효과음 7개 | 없음 |
| `node Design/tools/textures.mjs` | 대체 텍스처 15장과 미리보기 | sharp(미리보기만) |
| `node Design/tools/karts.mjs [RetireX 리소스팩 경로]` | 카트 썸네일·실루엣 | RetireX 리소스팩(운영자 PC) |

- sharp가 없으면 `npm i sharp`(저장소 밖에 설치해도 됨)로 설치한다.
- 스타일 가이드의 색을 바꾸면 `palette.mjs`의 표와 각 도구 맨 위의 색 상수를 함께 바꾼다.

## 4. 남은 일과 알려 둘 점

1. **Galmuri 폰트 파일**: 공식 저장소에서 받아 `Design/fonts/`에 넣는다(`Design/fonts/README.md`). 받은 뒤 목업 제목도 바꿀 수 있다.
2. **엔진음 루프**(결정 20-6): RetireX Online 세션이 RetireX 엔진음(`sounds/kart/lemon_engine_*`)을 바탕으로 준비한다. 출처·라이선스 확인 후 `Assets/sfx/`에 넣는다.
3. **앱 이름**: 결정 7번은 보류 상태다. 후보만 `Design/proposals/app-name.md`에 두었다.
4. **카트 실루엣**은 자동으로 뽑은 초안이다. 24 px에서 차종 구분이 약하니 필요하면 손으로 다듬는다. `gospel` 썸네일은 원본 렌더부터 앞코가 잘려 있다.
5. **곡선 타일 안쪽 모서리에는 벽이 없다**(바깥 L자 벽만 있음). 트랙 안쪽 잔디로 나갈 수 있다. 막아야 하면 테크와 상의한다.
6. **용량**: 새 파일은 194개, 약 26 MB다. 대부분은 참고 렌더(`Design/reference/retirex/tracks`, 24 MB)다. PRD 12장은 `.png`/`.wav`/`.glb`를 LFS로 추적한다고 했지만, 지금 `.gitattributes`에는 LFS 설정이 없다. 커밋 전에 테크와 정한다.
7. 참고 렌더(`render_*.png`)와 카드 그림(`card.png`)에는 마인크래프트 텍스처가 보인다. **참고용으로만** 쓴다. 앱·스토어·홍보 이미지에는 쓰지 않는다.
8. PRD 15장 체크박스와 `Docs/TechTask.md`는 고치지 않았다. 확인 후 디자이너나 테크가 체크한다.
