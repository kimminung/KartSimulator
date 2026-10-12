import SwiftUI

/// 트랙 평면도(결정 57·60): JSON의 `path`(중심선, 미터)를 주어진 크기에 맞춰 그린다. 시작 화면 카드 썸네일과 iOS 2D 미니맵이 같이 쓴다.
/// - `flipped`: 디오라마는 트랙을 180° 돌려 보여 주므로(`ScenePlacement` 씬 yaw π, 결정 43·44) visionOS 카드는 x·z를 뒤집어 박스와 맞춘다.
///   iOS 탑뷰 카메라는 북(−z)이 화면 위라 뒤집지 않는다.
/// - `kart`: 카트 평면 위치(xz, 미터)·heading을 주면 마커(화살표)를 그린다.
struct TrackPlanCanvas: View {
    let track: TrackDefinition
    var flipped = false
    var kart: (position: SIMD2<Float>, heading: Float)?
    var checkpointsPassed = 0

    var body: some View {
        Canvas { context, size in
            let points = track.path.map(\.vector)
            guard points.count > 2,
                  let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minZ = points.map(\.y).min(), let maxZ = points.map(\.y).max() else { return }
            let inset: CGFloat = 12
            let span = CGFloat(max(maxX - minX, maxZ - minZ, 0.001))
            let scale = (min(size.width, size.height) - inset * 2) / span
            let offsetX = (size.width - CGFloat(maxX - minX) * scale) / 2
            let offsetY = (size.height - CGFloat(maxZ - minZ) * scale) / 2
            func point(_ p: SIMD2<Float>) -> CGPoint {
                let x = offsetX + CGFloat(p.x - minX) * scale
                let y = offsetY + CGFloat(p.y - minZ) * scale
                return flipped ? CGPoint(x: size.width - x, y: size.height - y) : CGPoint(x: x, y: y)
            }
            var path = Path()
            path.move(to: point(points[0]))
            for p in points.dropFirst() { path.addLine(to: point(p)) }
            path.closeSubpath()
            let roadWidth = max(CGFloat(track.width) * scale, 4)
            let mm = track.theme?.minimap
            context.stroke(path, with: .color(Color.style(mm?.edge ?? StylePalette.mmEdge)), style: StrokeStyle(lineWidth: roadWidth * 1.5, lineJoin: .round))
            context.stroke(path, with: .color(Color.style(mm?.road ?? StylePalette.mmRoad)), style: StrokeStyle(lineWidth: roadWidth, lineJoin: .round))
            // 고가 구간(노면 0.8 m 이상)은 강조색 띠
            if let frames = track.frames, frames.count == points.count {
                var band = Path()
                var open = false
                for (i, f) in frames.enumerated() {
                    if f.count > 1, f[1] > 0.8 {
                        if open { band.addLine(to: point(points[i])) } else { band.move(to: point(points[i])); open = true }
                    } else { open = false }
                }
                context.stroke(band, with: .color(Color.style(mm?.accent ?? StylePalette.uiSky)), style: StrokeStyle(lineWidth: roadWidth * 0.45, lineCap: .round))
            }
            // 체크포인트: 통과 전 흐린 점, 통과 후 강조색
            for (ordinal, index) in track.checkpoints.enumerated() where index < points.count {
                let c = point(points[index])
                let passed = ordinal < checkpointsPassed
                let r: CGFloat = 3.5
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .color(passed ? Color.style(StylePalette.uiCyan) : Color.white.opacity(0.4)))
            }
            // 출발점
            let start = point(points[min(track.start.pathIndex, points.count - 1)])
            context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(Color.style(StylePalette.uiSky)))
            // 카트 마커: heading h의 전진 = (−sin h, −cos h) → 화면 방향으로 변환
            if let kart {
                let c = point(kart.position)
                var dir = CGPoint(x: CGFloat(-sin(kart.heading)), y: CGFloat(-cos(kart.heading)))
                if flipped { dir = CGPoint(x: -dir.x, y: -dir.y) }
                let len: CGFloat = 7
                var arrow = Path()
                arrow.move(to: CGPoint(x: c.x + dir.x * len, y: c.y + dir.y * len))
                arrow.addLine(to: CGPoint(x: c.x - dir.y * len * 0.6 - dir.x * len * 0.6, y: c.y + dir.x * len * 0.6 - dir.y * len * 0.6))
                arrow.addLine(to: CGPoint(x: c.x + dir.y * len * 0.6 - dir.x * len * 0.6, y: c.y - dir.x * len * 0.6 - dir.y * len * 0.6))
                arrow.closeSubpath()
                context.fill(arrow, with: .color(Color.style(StylePalette.uiGold)))
            }
        }
    }
}
