import Foundation

/// 세 가지 운전 모드. 어지러움증 대응을 위해 몰입도가 다른 선택지를 둔다(결정 39).
/// - `diorama`: 지금까지의 기본 모습 — 박스를 밖에서 내려다보며 카트를 조종.
/// - `firstPerson`: 트랙이 실제 크기로 존재하고(Phase 2), 머리 방향(헤드 포즈)으로 조향.
/// - `thirdPerson`: `firstPerson`과 같은 시점/크기지만, 조향은 이 프로젝트가 맨 처음 썼던
///   한손 핀치 좌/우회전 방식.
public enum ExperienceMode: String, CaseIterable, Sendable {
    case diorama
    case firstPerson
    case thirdPerson
}
