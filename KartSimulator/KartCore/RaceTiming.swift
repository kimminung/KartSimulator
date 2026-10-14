import Foundation

/// 레이스 흐름의 공용 시간 값(결정 65, Issue #60). visionOS 박스와 iOS 레이스 화면이 같은 값을 쓴다.
public enum RaceTiming {
    /// 카운트다운 숫자 하나의 유지 시간. 디자인 전달 준비음 `stttt.m4a`(약 2.997초)가 끝난 뒤 다음 숫자·준비음이 나오도록
    /// 3.1초(`Assets/sfx/countdown/countdown_spec.json`). 0초 3 → 3.1초 2 → 6.2초 1 → 9.3초 GO.
    public static let countdownStepSeconds: Double = 3.1
    /// GO 표시가 남는 시간.
    public static let goFlashSeconds: Double = 0.8
    /// 랩 진입 배너(일반 랩 / FINAL LAP)가 떠 있는 시간.
    public static let lapBannerSeconds: Double = 1.8
}
