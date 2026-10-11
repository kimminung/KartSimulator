import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// `Design/style-guide.md` 1장 색 표 — RetireX 색 체계(디자인 결정 20-11). SwiftUI(`Color`,
/// HUD 등)와 RealityKit(`UIColor`, 트랙 시각화 머티리얼) 양쪽에서 같은 이름으로 쓴다.
enum StylePalette {
    // 1-1. 트랙(3D 타일)
    static let grass = "#546D33"
    static let road = "#15151A"
    static let roadAlt = "#08090E"
    static let edgeLine = "#F9C628"
    static let curb = "#6C6D67"
    static let rail = "#A5A6AB"
    static let laneLine = "#EAECED"

    // 1-2. UI(메뉴·HUD)
    static let uiNight = "#000918"
    static let uiPanel = "#010B1A"
    static let uiWell = "#0D1729"
    static let uiRim = "#223A60"
    static let uiCyan = "#00F6F9" // 주 강조: 선택 테두리, 주 버튼, 체크포인트 통과, 핀치 표시
    static let uiSky = "#1DB8E6" // 게이지·진행 막대, 궤적 선
    static let uiGold = "#FEDA34" // 기록·순위 강조
    static let uiInk = "#F2F9FF" // 글자(살짝 차가운 흰색)
    static let uiWarn = "#FF3236" // 경고
    static let uiGreen = "#56E27A"
    static let uiMagenta = "#FF5CD6"

    // 1-4. 미니맵
    static let mmRoad = "#F4F7EC"
    static let mmEdge = "#142737"
    static let mmFinish = "#22B4DD" // 결승선, 출발 점
}

extension Color {
    static func style(_ hex: String) -> Color { Color(hex: hex) }
}

#if canImport(UIKit)
extension UIColor {
    static func style(_ hex: String) -> UIColor { UIColor(hex: hex) }
}
#endif
