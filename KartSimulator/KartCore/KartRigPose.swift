import Foundation

/// 카트 리그 움직임 튜닝(디자인 PRD 4-0, Issue #26, 결정 51). RetireX `physics` 애니메이션 식을 옮긴 값.
public struct KartRigTuning: Sendable {
    /// 핸들 최대 회전(도). 왼손만 핀치 = 왼쪽(+), 오른손만 핀치 = 오른쪽(−).
    public var steeringWheelDegrees: Float
    /// 앞바퀴 조향 최대(도). 바퀴 노드가 USDZ에 남아 있을 때만 쓰인다.
    public var frontWheelSteerDegrees: Float
    /// 조향 입력 평활 `lerp(dt × steerLerpRate)` (RetireX 14 ≈ 0.07 s).
    public var steerLerpRate: Float
    /// 회전 중 차체 바깥쪽 roll 최대(도), 속도비에 비례.
    public var bodyRollDegrees: Float
    /// 가감속 pitch 최대(도). 가속하면 뒤로(+), 감속하면 앞으로(−).
    public var bodyPitchDegrees: Float
    /// 차체 기울기 평활 `lerp(dt × bodyLerpRate)` (RetireX 10).
    public var bodyLerpRate: Float

    public init(
        steeringWheelDegrees: Float = 82,
        frontWheelSteerDegrees: Float = 30,
        steerLerpRate: Float = 14,
        bodyRollDegrees: Float = 4,
        bodyPitchDegrees: Float = 1.5,
        bodyLerpRate: Float = 10
    ) {
        self.steeringWheelDegrees = steeringWheelDegrees
        self.frontWheelSteerDegrees = frontWheelSteerDegrees
        self.steerLerpRate = steerLerpRate
        self.bodyRollDegrees = bodyRollDegrees
        self.bodyPitchDegrees = bodyPitchDegrees
        self.bodyLerpRate = bodyLerpRate
    }
}

/// 손 입력·속도에서 핸들·앞바퀴·차체 자세 각도를 매 프레임 계산한다(순수 값, RealityKit 없이 테스트).
/// 각도는 전부 **도(degree)**, 부호: 조향 +1 = 왼쪽.
public struct KartRigPose: Equatable, Sendable {
    /// 평활된 조향 입력 −1(오른쪽)…+1(왼쪽).
    public private(set) var steer: Float = 0
    /// 평활된 roll(도, 바깥쪽이 양수가 되도록 부호는 호출자가 축에 맞춰 적용).
    public private(set) var roll: Float = 0
    /// 평활된 pitch(도).
    public private(set) var pitch: Float = 0
    /// 바퀴 굴림 누적 각도(도). 앞으로 가면 증가.
    public private(set) var wheelSpin: Float = 0

    public init() {}

    public var steeringWheelDegrees: Float { steer * 82 }

    /// `drive`: 손 입력, `speed`: m/s(후진 음수), `maxSpeed`: 튜닝 최고 속도, `acceleration`: 이번 프레임 가속도(m/s²),
    /// `wheelRadius`: 바퀴 반지름(m, 굴림 각속도 = speed / r).
    public mutating func update(drive: DriveState, speed: Float, maxSpeed: Float, acceleration: Float, wheelRadius: Float, deltaTime: Float, tuning: KartRigTuning) {
        let dt = max(deltaTime, 0)
        let targetSteer: Float
        switch drive {
        case .turnLeft: targetSteer = 1
        case .turnRight: targetSteer = -1
        default: targetSteer = 0
        }
        steer += (targetSteer - steer) * min(1, dt * tuning.steerLerpRate)

        let speedRatio = min(abs(speed) / max(maxSpeed, 0.001), 1)
        // RetireX: roll = −steering × |wheel_speed| × k — 왼쪽으로 돌면(steer +) 차체는 오른쪽(바깥)으로 기운다.
        let targetRoll = -steer * speedRatio * tuning.bodyRollDegrees
        let accelRatio = min(max(acceleration / max(maxSpeed, 0.001), -1), 1)
        let targetPitch = accelRatio * tuning.bodyPitchDegrees
        let bodyAlpha = min(1, dt * tuning.bodyLerpRate)
        roll += (targetRoll - roll) * bodyAlpha
        pitch += (targetPitch - pitch) * bodyAlpha

        if wheelRadius > 0.0001 {
            wheelSpin += speed / wheelRadius * dt * 180 / .pi
            wheelSpin = wheelSpin.truncatingRemainder(dividingBy: 360)
        }
    }

    public func steeringWheelAngle(tuning: KartRigTuning) -> Float { steer * tuning.steeringWheelDegrees }
    public func frontWheelAngle(tuning: KartRigTuning) -> Float { steer * tuning.frontWheelSteerDegrees }
}
