import Foundation

/// iOS/iPadOS 터치 조작(결정 60, Issue #49) — 핀치 규칙과 1:1 대응.
/// 화면 왼쪽 반·오른쪽 반이 각각 "왼손·오른손 핀치"다.
/// - 양쪽 누름 = 양손 핀치 유지 → 전진
/// - 양쪽 누른 채 어느 쪽이든 아래로 끌기 = 핀치한 채 벌리기 → 후진(데드밴드 뒤 거리에 비례)
/// - 왼쪽만 = 왼손만 핀치 → 좌회전, 오른쪽만 = 우회전
/// - 아무것도 안 누름 = 양손 해제 → 정지
public struct TouchInputResolver: Equatable, Sendable {
    public struct Tuning: Equatable, Sendable {
        /// 후진이 시작되는 아래쪽 드래그 거리(pt). 핀치의 "기준 간격 + 4 cm"에 해당.
        public var reverseDeadbandPoints: Float
        /// 최대 후진까지의 추가 드래그 거리(pt). 핀치의 "25 cm 더 벌리기"에 해당.
        public var reverseSpanPoints: Float

        public init(reverseDeadbandPoints: Float = 40, reverseSpanPoints: Float = 160) {
            self.reverseDeadbandPoints = reverseDeadbandPoints
            self.reverseSpanPoints = reverseSpanPoints
        }
    }

    /// 한쪽 터치 상태: 누르고 있는지, 시작점 기준 세로 이동(pt, 아래 +).
    public struct Side: Equatable, Sendable {
        public var isDown: Bool
        public var dragDown: Float

        public init(isDown: Bool = false, dragDown: Float = 0) {
            self.isDown = isDown
            self.dragDown = dragDown
        }
    }

    public var left = Side()
    public var right = Side()
    public var tuning = Tuning()

    public init(tuning: Tuning = Tuning()) {
        self.tuning = tuning
    }

    /// 지금 입력을 `DriveState`로 바꾼다. 손 상태(`HandStatus`)도 함께 돌려 HUD 핀치 표시를 그대로 쓴다.
    public func resolve() -> (drive: DriveState, left: HandStatus, right: HandStatus) {
        let l = HandStatus(tracked: true, pinching: left.isDown)
        let r = HandStatus(tracked: true, pinching: right.isDown)
        switch (left.isDown, right.isDown) {
        case (true, true):
            let drag = max(left.dragDown, right.dragDown)
            let beyond = drag - tuning.reverseDeadbandPoints
            if beyond > 0 {
                let amount = min(beyond / max(tuning.reverseSpanPoints, 1), 1)
                return (.pedal(-amount), l, r)
            }
            return (.pedal(1), l, r)
        case (true, false):
            return (.turnLeft, l, r)
        case (false, true):
            return (.turnRight, l, r)
        case (false, false):
            return (.stopped, l, r)
        }
    }
}
