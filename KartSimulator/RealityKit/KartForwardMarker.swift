#if os(visionOS) || os(iOS)
import Foundation
import RealityKit

/// 카트 계층에서 차 앞을 뜻하는 마커 엔티티를 찾아, 그 방향을 주행 수학의 정면 축인 로컬 **-Z**로 보내는 Y축 보정 각도를
/// 계산한다(`KartForwardCorrection`, 결정 29·42번). 마커가 없으면 `fallbackDegrees`를 그대로 쓴다. visionOS 박스와 iOS 레이스
/// 화면이 같은 보정을 쓰도록 분리했다(결정 60).
///
/// 결정 32번에서 목표를 +Z로 뒤집었던 적이 있는데, 그건 손 좌표 변환 버그(결정 33번)로 카트가 실제로 후진하던 것을 모델이
/// 뒤집힌 것으로 오인한 수정이었다. 실기기에서 "뒷부분부터 전진"으로 다시 보고되어 -Z로 되돌렸다(결정 42번).
enum KartForwardMarker {
    /// 차 앞을 뜻하는 노드 이름(RetireX 원본 그대로, 소문자 비교). 앞에 있는 이름을 우선한다. 이름 **정확 일치**만 쓴다(Issue #23):
    /// 부분 일치 "front"는 razr에서 `front_l`(앞왼 바퀴 묶음)이 먼저 걸려 카트가 옆으로 비틀려 보였다.
    static let names = ["front_aero", "race_nose", "nose", "front"]

    @MainActor
    static func correctionAngle(for entity: Entity, fallbackDegrees: Float) -> Float {
        guard let front = findDescendant(in: entity, namedOneOf: names) else {
            debugLog("DEBUG-FRONT 정면 마커(\(names))를 못 찾음 — fallback \(fallbackDegrees)도 사용")
            return fallbackDegrees * .pi / 180
        }
        let nose = front.position(relativeTo: entity)
        guard let angle = KartForwardCorrection.angle(noseX: nose.x, noseZ: nose.z) else {
            debugLog("DEBUG-FRONT '\(front.name)' 위치가 원점과 거의 같아 방향을 못 구함 — fallback \(fallbackDegrees)도 사용")
            return fallbackDegrees * .pi / 180
        }
        let after = KartForwardCorrection.rotatedXZ(noseX: nose.x, noseZ: nose.z, by: angle)
        debugLog("DEBUG-FRONT '\(front.name)' 위치=\(nose) → 보정 \(angle * 180 / .pi)도, 보정 후 nose XZ=\(after) (목표 (0, -1))")
        return angle
    }

    @MainActor
    static func findDescendant(in entity: Entity, namedOneOf names: [String]) -> Entity? {
        for name in names {
            if let found = findDescendant(in: entity, namedExactly: name) { return found }
        }
        return nil
    }

    @MainActor
    static func findDescendant(in entity: Entity, namedExactly name: String) -> Entity? {
        if entity.name.lowercased() == name { return entity }
        for child in entity.children {
            if let found = findDescendant(in: child, namedExactly: name) { return found }
        }
        return nil
    }
}
#endif
