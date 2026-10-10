import Observation

@Observable
final class KartSelectionModel {
    var selectedKartID: String
    var selectedColorID: String?

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
