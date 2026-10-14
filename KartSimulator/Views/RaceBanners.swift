import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 디자인 전달 배너 그림(`Resources/Banners/`, 결정 63·65, Issue #62): 카운트다운 `count_3/2/1`·`go`, 랩 진입 `lap_2`~`lap_99`,
/// 마지막 랩 `final_lap`. 픽셀 그림이라 최근접 확대.
enum RaceBanners {
    /// 카운트다운 표시 텍스트("3"/"2"/"1"/"GO") → 파일 이름.
    static func countdownImageName(for text: String) -> String? {
        switch text {
        case "3": return "count_3"
        case "2": return "count_2"
        case "1": return "count_1"
        case "GO": return "go"
        default: return nil
        }
    }

    /// 랩 `lap`에 들어갈 때 보여 줄 배너. 1랩은 없음(출발), 마지막 랩은 FINAL LAP, 그 외 2~99는 일반 랩. 완주에는 부르지 않는다.
    static func lapBannerName(lap: Int, totalLaps: Int) -> String? {
        guard lap >= 2 else { return nil }
        if lap == totalLaps { return "final_lap" }
        return lap <= 99 ? "lap_\(lap)" : nil
    }

    static func image(named name: String) -> Image? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    static func cgImage(named name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)?.cgImage
    }
    #endif
}

/// 배너 한 장(높이 고정, 비율 유지, 최근접 확대).
struct BannerImage: View {
    let name: String
    var height: CGFloat = 60

    var body: some View {
        if let image = RaceBanners.image(named: name) {
            image
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
    }
}
