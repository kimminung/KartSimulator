import Foundation

/// 개발용 로그(결정 59, Issue #46). `DEBUG` 빌드에서만 콘솔에 찍고 Release(아카이브)에서는 완전히 비운다 —
/// 손 제스처·주행·레이아웃 로그는 실기기 진단에 계속 쓰므로 지우지 않고 빌드 플래그로 끈다.
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
