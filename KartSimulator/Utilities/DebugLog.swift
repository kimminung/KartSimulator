import Foundation
import os

/// 개발용 로그(결정 59, Issue #46). `DEBUG` 빌드에서만 Xcode 콘솔(`print`)과 통합 로그(`Logger`, 서브시스템 `com.kimminung.kart`)에
/// 남기고 Release(아카이브)에서는 완전히 비운다 — 손 제스처·주행·레이아웃·PERF 로그는 실기기 진단에 계속 쓰므로 지우지 않고
/// 빌드 플래그로 끈다. 통합 로그에도 쓰는 이유: 시뮬레이터에서 `xcrun simctl spawn <udid> log stream --process KartSimulator`로
/// Xcode 없이도 읽을 수 있다(결정 61 성능 측정).
#if DEBUG
private let debugLogger = Logger(subsystem: "com.kimminung.kart", category: "debug")
#endif

@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    let text = message()
    print(text)
    debugLogger.notice("\(text, privacy: .public)")
    #endif
}
