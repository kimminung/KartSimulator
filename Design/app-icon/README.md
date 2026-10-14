# 가스펠 앱 아이콘 전달본

2026-10-14 · 디자인 · 결정 62 · 사용자 검토 대기

핀치 로버의 대표 카트 `gospel` 앞모습으로 만든 아이콘이다. 바탕화면의 `1.png`·`2.png`를 구도 참고로 쓰고, `gospel.bbmodel` 원본을 직접 렌더링했다. 검정 도색의 짙은 차체, 시안 라인, 앞 범퍼, 좌석과 핸들을 유지했다. 사용자 피드백에 따라 전체 카트를 유지하며 앞부분이 더 크게 보이는 낮은 정면 원근 구도로 바꿨다. 앞부분만 잘라 쓰거나 뒤쪽 부품을 제외하지 않는다. AI 이미지 생성은 쓰지 않았다.

## 전달 파일

| 대상 | 파일 | 규격 |
| --- | --- | --- |
| visionOS | `visionos/AppIcon.solidimagestack/` | Back / Middle / Front, 각 1024×1024 PNG |
| iOS·iPadOS | `ios/AppIcon.appiconset/` | `icon_1024.png`, 1024×1024 RGB, 알파 없음 |
| 전체 비교 | `preview.png` | 원형·둥근 사각형 미리보기, 128·64·32 px 확인, 레이어 비교 |
| visionOS 미리보기 | `preview-visionos.png` | 원형 마스크를 적용한 검토용 이미지 |
| iOS 미리보기 | `preview-ios.png` | 둥근 사각형 마스크를 적용한 검토용 이미지 |
| 원본 렌더 | `master/gospel-front-2048.png` | 2048×2048, 투명 배경 |
| 합성 마스터 | `master/composite.png` | 마스크 없는 1024×1024 RGB |

실제 전달 PNG에는 원형·둥근 모서리를 미리 자르지 않았다. 시스템이 마스크를 적용한다. Apple 문서의 visionOS 1024 px 레이어 규격과 현재 프로젝트의 에셋 카탈로그 구조를 따른다.

- [Apple 앱 아이콘 가이드](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [Xcode 에셋 카탈로그 아이콘 설정](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)

## 레이어 구성

| 순서 | 내용 | 투명도 |
| --- | --- | --- |
| Back | `ui-rim` → `ui-night` 그라데이션, `ui-sky` 은은한 중심광 | RGB 불투명 |
| Middle | 좌석, 핸들, 뒤쪽 차체와 뒤 바퀴 | RGBA, 투명 배경 |
| Front | 앞쪽 보닛, 범퍼, 앞 바퀴와 시안 라인 | RGBA, 투명 배경 |

앞뒤를 같은 그림으로 복제하지 않았다. 모델 부품을 나눠 깊이 버퍼로 가림을 계산했다. Middle에는 Front 뒤에 가려지는 차체도 있어 작은 시차 이동 때 빈틈이 드러나는 것을 줄인다. 레이어별 시스템 이동과 광택은 Xcode·Vision Pro에서 최종 확인해야 한다.

카메라는 정면에서 위로 25°인 원근 구도다. 모델 유닛 기준 목표점은 `(0, 9, −14)`, 거리는 68이다. 앞 보닛·범퍼가 좌석·뒤쪽 차체보다 가깝고 크게 보인다. 모델의 큐브 239개를 모두 렌더링한다. 원형 마스크 안의 최대 반경은 약 480 px이며 가장자리 여유는 약 32 px다. 이 값은 로컬 합성 이미지 기준이며 시스템 안전 영역 전체를 보증하는 값은 아니다.

배경은 `Design/style-guide.md`의 `ui-rim`(`#223A60`), `ui-night`(`#000918`), `ui-sky`(`#1DB8E6`)를 쓴다. 차체 색은 사용자 원본의 `gospel_black.png`에서 가져왔다. 추가 문구·손 그림·트랙 장식은 넣지 않았다.

## 원본과 재생성

- `source/gospel.bbmodel`: 바탕화면 원본의 바이트 동일 사본. 모델링·피벗·UV 수정 없음.
- `source/reference_01.png`, `source/reference_02.png`: 바탕화면 `1.png`·`2.png`의 바이트 동일 사본.
- `source/gospel_black.png`: bbmodel 내장 PNG를 그대로 추출한 파일.
- `source/background.svg`: 배경 벡터 원본.
- `composition.json`: 원근 카메라 각도·거리·목표점, 전체 카트 배치 크기, 배경 색과 레이어 분할 기준.
- `build.mjs`: Node.js와 sharp를 사용하는 렌더·레이어·카탈로그·미리보기 생성기.
- `manifest.sha256`: 전달 파일의 SHA-256 목록. 재생성할 때 함께 갱신한다. 폴더 안 텍스트는 LF로 고정하고 bbmodel은 Git 줄바꿈 변환도 하지 않아 체크아웃 뒤 바이트가 바뀌는 것을 막는다.

저장소 루트에서 실행한다.

```powershell
node Design/app-icon/build.mjs
```

이 PC에서는 C:에 설치된 Node.js와 번들 sharp를 쓴다. 다른 환경에서는 `sharp` 패키지가 필요하다. Python·Blender·Blockbench 자동 조작은 필요하지 않다.

원본 텍스처의 알파 8 픽셀에는 시안 라인과 전조등 색이 들어 있다. 렌더러는 이를 투명도 컷오프로 버리지 않고 표면색으로 살린다. 알파 0인 빈 영역만 제외한다. 모델과 텍스처 파일은 바꾸지 않는다.

## 확인 결과와 테크 적용

`validation.json`에 PNG 크기·채널·sRGB, 앞뒤 레이어 표시 면적, 원형 마스크 밖 픽셀 수, 레이어 합성과 전체 모델 렌더의 차이, 시안 라인 표시 수를 기록했다. 원본과 사본의 SHA-256도 대조했다. 정면 형태, 작은 크기, 원형·둥근 사각형 마스크와 레이어 미리보기를 이미지로 확인했다.

현재 `KartSimulator/Assets.xcassets/`의 자리표시자는 그대로다. 테크는 사용자가 디자인을 승인한 뒤 다음 두 폴더를 같은 이름의 기존 아이콘과 교체하면 된다.

1. `visionos/AppIcon.solidimagestack/` → `KartSimulator/Assets.xcassets/AppIcon.solidimagestack/`
2. `ios/AppIcon.appiconset/` → `KartSimulator/Assets.xcassets/AppIcon.appiconset/`

`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`은 유지한다. iOS 전달본은 현재 프로젝트의 PNG 에셋 카탈로그용이다. Icon Composer의 `.icon` 파일은 이번 전달에 포함하지 않았다.

이 PC에서 Xcode 에셋 컴파일, Vision Pro 홈 화면의 레이어 시차, iPhone·iPad 홈 화면은 확인하지 않았다. GitHub 푸시·PR·Issue 작성은 하지 않았다.

## 입력 SHA-256

| 원본 | SHA-256 |
| --- | --- |
| `gospel.bbmodel` | `50EBB5A032CDB651A35BE342954C40DF0414C9C92F80D43BE7BA0BF1BCE692CC` |
| `1.png` | `FA282BFDB2A695207F51D54BB605BB1401DF45CDA04927F65601D9BDD5A3A2AA` |
| `2.png` | `BEBF906DEB95203343E7BA5A553DA33790B4AE0FFB3ACDFF55B8FEC0F700B885` |
