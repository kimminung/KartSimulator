import Foundation

struct KartColorOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let swatchHex: String
}

struct KartModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let usdzResourceName: String
    let colorOptions: [KartColorOption]
    /// "front" 이름 마커를 못 찾았을 때만 쓰는 보정값(도). 이 로스터는 정면을 로컬 +Z로 export했고
    /// 주행 수학은 정면 = 로컬 -Z를 전제로 하므로 180도가 맞다(결정 27·42번). 결정 32번에서 0으로
    /// 바꿨던 것은 손 좌표 버그(결정 33번)로 인한 오진이었다. 마커가 있으면 이 값은 쓰이지 않는다
    /// (`ImmersiveBoxView.frontCorrectionAngle` → `KartForwardCorrection`).
    let modelForwardCorrectionDegrees: Float = 180

    var hasColorVariants: Bool { !colorOptions.isEmpty }
}

enum KartCatalog {
    /// `Design/style-guide.md` 1-3장 "카트 도색 17색" 표 그대로(RetireX 색 번호 기준, 결정 20-2·20-11).
    /// 순서는 빨강에서 색상환을 한 바퀴 돈 뒤, 흰색에서 검정까지 무채색.
    static let standardColors: [KartColorOption] = [
        KartColorOption(id: "red", displayName: "레드", swatchHex: "#EE4949"),
        KartColorOption(id: "orange", displayName: "오렌지", swatchHex: "#F28C28"),
        KartColorOption(id: "yellow", displayName: "옐로우", swatchHex: "#F7D439"),
        KartColorOption(id: "lime", displayName: "라임", swatchHex: "#7BB82A"),
        KartColorOption(id: "green", displayName: "그린", swatchHex: "#478143"),
        KartColorOption(id: "cyan", displayName: "시안", swatchHex: "#27A5A8"),
        KartColorOption(id: "light_blue", displayName: "라이트블루", swatchHex: "#55B9E7"),
        KartColorOption(id: "blue", displayName: "블루", swatchHex: "#345CDC"),
        KartColorOption(id: "purple", displayName: "퍼플", swatchHex: "#884BC3"),
        KartColorOption(id: "magenta", displayName: "마젠타", swatchHex: "#C853D5"),
        KartColorOption(id: "pink", displayName: "핑크", swatchHex: "#EF88AD"),
        KartColorOption(id: "brown", displayName: "브라운", swatchHex: "#825637"),
        KartColorOption(id: "white", displayName: "화이트", swatchHex: "#F1F2EE"),
        KartColorOption(id: "undyed", displayName: "기본", swatchHex: "#D5DCE5"),
        KartColorOption(id: "silver", displayName: "실버", swatchHex: "#A5ADB2"),
        KartColorOption(id: "gray", displayName: "그레이", swatchHex: "#484D58"),
        KartColorOption(id: "black", displayName: "블랙", swatchHex: "#252934"),
    ]

    // 5종 최종 로스터 — `mms`는 카트가 아니라 일반 자동차 모델이라 제외 (디자인 결정 20-7·20-8).
    static let karts: [KartModel] = [
        KartModel(id: "arcrix", displayName: "Arcrix", usdzResourceName: "arcrix", colorOptions: standardColors),
        KartModel(id: "bogubkart", displayName: "Bogub Kart", usdzResourceName: "bogubkart", colorOptions: standardColors),
        KartModel(id: "gospel", displayName: "Gospel", usdzResourceName: "gospel", colorOptions: standardColors),
        KartModel(id: "razr", displayName: "Razr", usdzResourceName: "razr", colorOptions: standardColors),
        KartModel(id: "sirius", displayName: "Sirius", usdzResourceName: "sirius", colorOptions: standardColors),
    ]
}
