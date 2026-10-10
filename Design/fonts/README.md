# 폰트

| 용도 | 폰트 | 라이선스 | 상태 |
| --- | --- | --- | --- |
| 앱 제목, 카운트다운 숫자 | **Galmuri**(갈무리) — 한글 픽셀 폰트, 제작 quiple | SIL Open Font License 1.1 | v2.40.4 받음: `Galmuri11-Bold.ttf`(제목), `Galmuri14.ttf`(카운트다운), `OFL.txt` |
| HUD 숫자 | SF Pro Rounded(시스템) | Apple 시스템 폰트 — 앱 안에서 시스템 폰트로 쓰는 것은 문제없음, 파일을 저장소에 넣지 않음 | 추가 작업 없음 |
| 라벨·본문 | SF Pro(시스템) | 위와 같음 | 추가 작업 없음 |

## Galmuri 넣는 법

1. 공식 저장소 `https://github.com/quiple/galmuri`의 Releases에서 최신 판을 받는다(ttf 또는 otf).
2. 쓰는 굵기만 이 폴더에 둔다. 제목·카운트다운에는 `Galmuri11-Bold`(또는 `Galmuri14`)를 권한다. 큰 글자(48~120 pt)에서 픽셀이 또렷하다.
3. 받은 묶음에 든 `OFL.txt`(라이선스 전문)를 이 폴더에 같이 둔다.
4. 앱 정보(설정·크레딧)에 "Galmuri © quiple, SIL Open Font License 1.1"을 적는다.

## OFL 1.1 요점

- 앱에 넣어 배포·판매해도 된다.
- 폰트 파일만 따로 판매하면 안 된다.
- 고쳐서 배포하려면 이름을 바꿔야 한다(그대로 쓰면 해당 없음).
- 라이선스 전문을 함께 배포한다.

## 목업에 관해

`Design/mockups/`의 화면은 Windows에서 그려 Galmuri 대신 맑은 고딕 굵게, SF Pro 대신 Segoe UI를 썼다. Galmuri를 넣은 뒤 `node Design/tools/mockups.mjs`의 `pixelTitle` 글꼴만 바꾸면 다시 그릴 수 있다.
