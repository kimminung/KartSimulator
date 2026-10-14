최종 복셀 운전자 디자인을 사용자 승인받았습니다. 헬멧·장갑 끝면, 착석 발목 분리, 바이저 양끝 수직선을 수정했습니다. 스티브 큐브·UV·스킨을 복사하지 않은 자체 28개 닫힌 메시·17개 관절·512×256 텍스처 2종입니다. 결정 64.

전달: `Assets/blockbench/driver/driver_01.bbmodel`, `Assets/export/glb/driver_01.glb`, `Design/driver/README.md`·preview.png·validation.json, `Design/karts/seats.md`.

- [ ] 관절 계층·피벗·최근접 텍스처·미터 단위·7개 클립을 보존해 USDZ 변환
- [ ] idle/walk/run/sit_down/floor_sit/kart_idle/kart_steer를 상태에 연결. 제자리 보행 클립과 앱 이동을 중복하지 않음
- [ ] 가스펠의 hip [0,0.715625,0.125] m 배치 확인. kart_idle의 root [0,−0.021875,0.125] m 이동을 다시 더하지 않고 카트 배율은 한 번만 적용
- [ ] 나머지 razr/arcrix/bogubkart/sirius 4종의 좌석·손·발 피팅 후 seats.md 갱신
- [ ] kart_steer의 ±12°는 검토 시연. 결정 48의 실제 핸들 최대 ±82° 및 평활을 따라 양손 접촉을 앱 입력 전 범위에서 맞춤
- [ ] 모든 클립의 발목 접합·헬멧 윗면·장갑 끝면·UV와 전환을 RealityKit 및 실기기에서 확인

Blockbench 렌더와 247개 키프레임 자세, 닫힌 면·UV·루프 이음새·발목 제한을 확인했습니다. GLB 공식 검증 오류·경고 0입니다. USDZ·실제 앱·다른 4종 피팅은 미완료입니다. 기존 #29·#26은 닫힌 배치·카트 움직임 이슈이며 승인 모델 도입 후속으로 별도 추적합니다.
