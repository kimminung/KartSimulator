import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 속도계(결정 63·65, Issue #59): 디자인 전달 103×79 레이어 4장(`Resources/HUD/`)을 같은 원점에 쌓고, 게이지는
/// `dial_spec.json`의 부채꼴(중심 (51.5, 52), 시작 172.875°, 시계 방향 194.25°)로 연속 마스킹한다. 눈금 0~20 km/h, 표시 배율 없음.
/// 실제 속도가 튜닝 최고 속도의 90 % 이상이면 부스트 앞 프레임. 가운데 숫자는 시스템 고정폭. 픽셀 이미지는 최근접 확대.
struct SpeedometerView: View {
    let speedKmh: Double
    /// 부스트 프레임 기준(km/h) = 0.9 × 최고 속도 × 3.6. 기본 12.96.
    var boostThresholdKmh: Double = 12.96
    /// 표시 배율(103×79 → 화면 pt). 2 = 206×158.
    var scale: CGFloat = 2

    private static let canvas = CGSize(width: 103, height: 79)
    private static let center = CGPoint(x: 51.5, y: 52)
    private static let startDegrees = 172.8749836510982
    private static let sweepDegrees = 194.2500326978036
    private static let numberRect = CGRect(x: 23, y: 31, width: 55, height: 25)
    private static let maximumKmh = 20.0

    var body: some View {
        let ratio = min(max(abs(speedKmh) / Self.maximumKmh, 0), 1)
        let boost = abs(speedKmh) >= boostThresholdKmh
        ZStack(alignment: .topLeading) {
            layer("speedometer_background")
            layer("speedometer_gauge")
                .mask(alignment: .topLeading) {
                    GaugeWedge(ratio: ratio)
                        .frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale)
                }
            layer(boost ? "speedometer_frame_boost" : "speedometer_frame")
            Text(String(format: "%.0f", abs(speedKmh)))
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.style(StylePalette.uiInk))
                .frame(width: Self.numberRect.width * scale, height: Self.numberRect.height * scale)
                .offset(x: Self.numberRect.minX * scale, y: Self.numberRect.minY * scale)
        }
        .frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "속도 %.0f km/h%@", abs(speedKmh), boost ? ", 부스트" : ""))
    }

    @ViewBuilder
    private func layer(_ name: String) -> some View {
        if let image = Self.loadImage(name) {
            image
                .interpolation(.none)
                .resizable()
                .frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale)
        } else {
            Color.clear.frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale)
        }
    }

    /// `Resources/HUD/`의 낱장 PNG는 Asset Catalog가 아니라 파일로 읽는다(카트 썸네일과 같은 방식).
    private static func loadImage(_ name: String) -> Image? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    /// 부채꼴 마스크: 왼쪽 아래에서 위를 지나 오른쪽 아래로(시계 방향) `ratio`만큼.
    private struct GaugeWedge: Shape {
        let ratio: Double

        func path(in rect: CGRect) -> Path {
            var path = Path()
            guard ratio > 0 else { return path }
            let s = rect.width / SpeedometerView.canvas.width
            let c = CGPoint(x: SpeedometerView.center.x * s, y: SpeedometerView.center.y * s)
            let radius = max(rect.width, rect.height) // 캔버스 전체를 덮는 반지름
            let start = Angle.degrees(SpeedometerView.startDegrees)
            let end = Angle.degrees(SpeedometerView.startDegrees + SpeedometerView.sweepDegrees * ratio)
            path.move(to: c)
            // SwiftUI 좌표(y 아래)에서 clockwise: false가 화면상 시계 방향으로 돈다
            path.addArc(center: c, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            path.closeSubpath()
            return path
        }
    }
}
