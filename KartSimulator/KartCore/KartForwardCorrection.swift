import Foundation

/// 카트 USDZ 모델의 "정면"을 주행 수학이 기대하는 축(로컬 **-Z**)으로 돌리는 Y축 보정 각도.
///
/// `KartMotionState`는 `forward = (-sin(h), 0, -cos(h))`로 움직이고, `kartSlot`은
/// `simd_quatf(angle: h, axis: Y)`로 돈다. 두 식은 "모델 정면이 로컬 -Z일 때" 카트가 바라보는
/// 방향과 나아가는 방향이 일치한다(결정 27번). 그래서 모델 안의 "front" 마커 위치가 어느 쪽을
/// 가리키든, 그 방향을 -Z로 보내는 회전을 한 번 더 걸어 준다(결정 29번).
///
/// 결정 32번에서 목표를 +Z로 뒤집었던 것은 잘못이었다 — 그때는 손 좌표 변환 버그(결정 33번) 때문에
/// 카트가 실제로 후진하고 있었고, 그걸 모델이 뒤집힌 것으로 보고 고친 것이다. 결정 42번에서 -Z로 되돌렸다.
/// 다시 뒤집히지 않도록 이 함수는 `KartCoreTests`에서 세 축 모두 검증한다.
public enum KartForwardCorrection {
    /// `nose`가 모델 로컬 좌표에서 "front" 마커가 있는 XZ 위치일 때, `R_y(φ)·nose`가 -Z를 향하게 하는 φ(라디안).
    /// 길이가 0에 가까우면 `nil`(방향을 알 수 없음).
    public static func angle(noseX: Float, noseZ: Float) -> Float? {
        guard (noseX * noseX + noseZ * noseZ).squareRoot() > 0.0001 else { return nil }
        // R_y(φ)·(x, z) = (x cosφ + z sinφ, -x sinφ + z cosφ). 이것이 (0, -r)가 되려면 φ = π/2 + atan2(z, x).
        return Float.pi / 2 + atan2(noseZ, noseX)
    }

    /// 보정이 적용된 뒤의 nose 방향(XZ, 단위 벡터). 테스트와 디버그 로그용.
    public static func rotatedXZ(noseX: Float, noseZ: Float, by angle: Float) -> SIMD2<Float> {
        let c = cos(angle), s = sin(angle)
        let v = SIMD2<Float>(noseX * c + noseZ * s, -noseX * s + noseZ * c)
        let len = (v.x * v.x + v.y * v.y).squareRoot()
        return len > 0 ? v / len : v
    }
}
