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
    /// "front" 이름 마커를 못 찾았을 때만 쓰는 보정값(도). 실기기 확인 결과 이 로스터는 마커가
    /// 로컬 +Z를 향한 상태가 정방향이라, 마커를 못 찾는 경우도 일단 보정 없음(0)으로 둔다
    /// (`ImmersiveBoxView.frontCorrectionAngle`, 결정 32번). 실기기에서 "카트가 뒤로 달린다"로
    /// 보이면 이 값을 조정한다.
    let modelForwardCorrectionDegrees: Float = 0

    var hasColorVariants: Bool { !colorOptions.isEmpty }
}

enum KartCatalog {
    /// 색상환(빨강→주황→...→보라→마젠타→핑크) 순으로 정렬, 갈색·무채색은 끝에 묶는다 (디자인 결정 20-2).
    static let standardColors: [KartColorOption] = [
        KartColorOption(id: "red", displayName: "레드", swatchHex: "#E8463A"),
        KartColorOption(id: "orange", displayName: "오렌지", swatchHex: "#F2994A"),
        KartColorOption(id: "yellow", displayName: "옐로우", swatchHex: "#F4D03F"),
        KartColorOption(id: "lime", displayName: "라임", swatchHex: "#B4E61D"),
        KartColorOption(id: "green", displayName: "그린", swatchHex: "#34A853"),
        KartColorOption(id: "cyan", displayName: "시안", swatchHex: "#2BC9D6"),
        KartColorOption(id: "light_blue", displayName: "라이트블루", swatchHex: "#6FB7F0"),
        KartColorOption(id: "blue", displayName: "블루", swatchHex: "#2F6FED"),
        KartColorOption(id: "purple", displayName: "퍼플", swatchHex: "#8E5FD6"),
        KartColorOption(id: "magenta", displayName: "마젠타", swatchHex: "#D6267E"),
        KartColorOption(id: "pink", displayName: "핑크", swatchHex: "#F5A6C6"),
        KartColorOption(id: "brown", displayName: "브라운", swatchHex: "#7B4B2A"),
        KartColorOption(id: "black", displayName: "블랙", swatchHex: "#1C1C1E"),
        KartColorOption(id: "gray", displayName: "그레이", swatchHex: "#8E8E93"),
        KartColorOption(id: "silver", displayName: "실버", swatchHex: "#C7C9CC"),
        KartColorOption(id: "white", displayName: "화이트", swatchHex: "#F5F5F5"),
        KartColorOption(id: "undyed", displayName: "기본", swatchHex: "#D9D4C7"),
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
