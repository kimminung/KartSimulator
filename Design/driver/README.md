# 탑승자 driver_01 — 사용자 승인본

사용자 지정 `resource_pack/models/entity/humanoid.custom.geo.json`의 사람형 관절 구조를 참고했다. 큐브·UV·스티브 스킨·Molang 클립은 복사하지 않았다. 헬멧·레이싱 수트·장갑·부츠를 새로 만들었다. 원본 RP와 기존 가스펠 파일은 읽기만 했다.

- 편집 원본: `Assets/blockbench/driver/driver_01.bbmodel`
- 신규 텍스처: 같은 폴더의 `driver_01_skin.png`, `driver_01_skin_night.png` — 512×256, 면별 UV·1픽셀 여유, 제한 팔레트의 픽셀 채색
- 앱 변환 입력: `Assets/export/glb/driver_01.glb` — 28개 닫힌 메시, 17개 관절, 미터 단위, Y 위·−Z 정면, 텍스처 내장
- 가스펠 피팅 검토본: `driver_01_gospel_review.bbmodel` — 원본 카트의 239큐브·검정 텍스처를 포함한 별도 검토 파일
- 이미지: `renders/`, 전체 검토판 `preview.png`

## 관절과 클립

`root → hip → body → neck → head`, 몸통 아래 좌우 `arm → forearm → hand`, 골반 아래 좌우 `thigh → shin → foot`로 나눴다. 팔꿈치·손목·무릎·발목은 실제 접합점에 피벗을 둔다. 발목은 착석 시 −5도, 보행·달리기에서도 ±20도를 넘지 않는다. 부츠 위의 닫힌 커프가 정강이와 이어진다.

| 클립 | 길이 | 재생 |
| --- | --- | --- |
| idle | 2.4초 | 반복 |
| walk | 1.1초 | 제자리 보행 반복 |
| run | 0.65초 | 제자리 달리기 반복 |
| sit_down | 0.85초 | 한 번, 바닥 앉기 전환 |
| floor_sit | 2초 | 바닥에 앉은 자세 유지 |
| kart_idle | 2초 | 가스펠 착석·핸들 잡기 유지 |
| kart_steer | 3초 | 좌우 조향 시연 ±12도 |

GLB에는 `animation.` 접두사가 붙은 같은 7개 클립을 넣었다. 모델에서 캐릭터를 이동시키는 루트 모션은 넣지 않았다. 앱에서 속도·상태에 따라 클립을 선택하고 보행 속도를 맞춘다. 조향 시연은 실제 입력을 연결하는 최종 컨트롤러가 아니다.

## 사용 지침과 검수

사용자 지정 [mcbemodelingmasterAI](https://github.com/iMasterProX/mcbemodelingmasterAI)의 `486c7f8`를 읽고 경사진 연결면, 닫힌 몸체, 관절 피벗, 위치 기준 채색과 렌더 검수 방법을 적용했다. [Blockbench Minecraft Style Guide](https://blockbench.net/wiki/guides/minecraft-style-guide/)의 색조가 변하는 제한 팔레트·픽셀 덩어리·엔티티 명암 원칙을 읽고, 바이저 반사·헬멧 패널·수트 주름·장갑 손가락·부츠 밑창을 다시 채색했다. 노이즈와 연속 RGB 그라데이션으로 디테일을 대신하지 않는다.

초안의 다각형 끝면은 Blockbench에서 표시되지 않는 결함이 있었다. 모든 면을 삼각형·사각형으로 바꾸고 헬멧 윗면·장갑·부츠 끝면을 막았다. 사용자가 지적한 바이저 양끝 수직선도 제거했다. 발을 수평으로 만드는 과도한 역회전 대신 정강이를 따르는 착석 자세로 수정했다.

`validation.json`에는 닫힌 메시·지원되는 면·UV 범위, 247개 키프레임 자세의 바닥 침범·루프 이음새·발목 한계, 내보낸 GLB 검증을 기록했다. 결함을 넣은 복사본에서 헬멧 윗면 누락·지원하지 않는 다각형·UV 범위 초과가 검출되는 것도 확인했다. 원본 및 GLB 확인은 앱에서의 정상 표시를 증명하지 않는다.

## USDZ 변환 인계

GLB를 Blender/Reality Composer Pro에서 불러올 때 관절 계층·피벗·미터 단위·클립을 보존한다. 메시를 하나로 합치거나 변환을 모두 적용해 애니메이션 피벗을 없애지 않는다. 픽셀 텍스처는 최근접 필터를 유지한다. USDZ로 변환한 뒤 모든 클립·좌우 방향·크기·텍스처·손과 핸들의 접촉을 RealityKit 화면에서 확인한다.

가스펠 로컬 배치의 `kart_idle`에는 root 이동 `[0,-0.35,2]` model units가 들어 있다. 카트의 자식으로 붙일 때 같은 이동을 두 번 적용하지 않는다. hip의 카트 좌표는 `[0,11.45,2]` units = `[0,0.715625,0.125]` m. Bedrock rideable의 발 기준 좌석 좌표와 혼동하지 않는다. 다른 카트 4종의 피팅·최종 USDZ·실제 앱 확인은 후속이며, 현 모델은 2026-10-14 최종 수정본을 사용자 승인받아 로컬 커밋 대상으로 확정했다. 원격 게시와 앱 적용은 후속이다.

## 다시 준비할 때

1. `node Design/driver/build.mjs` — 자체 모델·UV·텍스처·클립 스펙 생성
2. 별도 빈 Blockbench free 프로젝트에서 `load-in-blockbench.mjs`
3. `render.mjs`, `export.mjs`, `validate.mjs`
4. `prepare-gospel-review.mjs` 이후 별도 빈 free 프로젝트에서 `render-gospel.mjs`

MCP 작업은 checkpoint와 별도 프로젝트를 사용했다. 사용자가 수작업한 원본은 다시 생성하지 말고, 수정본을 새 기준으로 삼는다. 초기 비교본은 저장소 밖 작업 보관 폴더에 두고 납품에서 제외했다. 생성 도구는 `generated-state.json`과 파일 해시가 다르면 중단한다. 수작업 수정본을 이 기준으로 자동 덮어쓰지 않는다. 검증에는 Node 22 이상과 `gltf-validator`, 미리보기에는 `sharp`가 필요하다. 설치는 저장소 밖 작업 폴더에서 한다.
