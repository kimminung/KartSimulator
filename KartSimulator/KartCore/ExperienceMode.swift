import Foundation

/// 운전 모드 2종 (결정 39에서 3종으로 시작했다가 결정 47·49에서 1인칭을 멀미로 폐기).
/// - `diorama`: 기본 모습 — 박스를 밖에서 내려다보며 카트를 조종.
/// - `thirdPerson`: 트랙이 실제 크기로 주변에 깔리고, 카트 뒤에서 카트 진행 방향을 보는 추적 시점(결정 44~47).
/// 두 모드의 손 조작은 완전히 같다(양손 핀치 유지 = 전진, 핀치한 채 벌리면 후진, 한손만 = 회전 — 결정 49).
public enum ExperienceMode: String, CaseIterable, Sendable {
    case diorama
    case thirdPerson
}
