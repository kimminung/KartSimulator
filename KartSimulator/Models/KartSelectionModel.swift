import Observation

@Observable
final class KartSelectionModel {
    var selectedKartID: String
    var selectedColorID: String?
    /// 시작 화면 트랙 카드(Issue #43). 박스가 열려 있는 동안 바꾸면 `ImmersiveBoxView`가 타일·미니맵·출발 위치를 다시 만든다.
    var selectedTrackID: String = TrackCatalog.trackIDs[0]

    init() {
        let first = KartCatalog.karts[0]
        selectedKartID = first.id
        selectedColorID = first.colorOptions.first?.id
    }

    var selectedKart: KartModel {
        KartCatalog.karts.first { $0.id == selectedKartID } ?? KartCatalog.karts[0]
    }

    func selectKart(_ kart: KartModel) {
        selectedKartID = kart.id
        selectedColorID = kart.colorOptions.first?.id
    }
}
