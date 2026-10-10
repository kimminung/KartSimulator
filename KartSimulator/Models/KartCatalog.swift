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

    var hasColorVariants: Bool { !colorOptions.isEmpty }
}

enum KartCatalog {
    static let standardColors: [KartColorOption] = [
        KartColorOption(id: "black", displayName: "블랙", swatchHex: "#1C1C1E"),
        KartColorOption(id: "blue", displayName: "블루", swatchHex: "#2F6FED"),
        KartColorOption(id: "brown", displayName: "브라운", swatchHex: "#7B4B2A"),
        KartColorOption(id: "cyan", displayName: "시안", swatchHex: "#2BC9D6"),
        KartColorOption(id: "gray", displayName: "그레이", swatchHex: "#8E8E93"),
        KartColorOption(id: "green", displayName: "그린", swatchHex: "#34A853"),
        KartColorOption(id: "light_blue", displayName: "라이트블루", swatchHex: "#6FB7F0"),
        KartColorOption(id: "lime", displayName: "라임", swatchHex: "#B4E61D"),
        KartColorOption(id: "magenta", displayName: "마젠타", swatchHex: "#D6267E"),
        KartColorOption(id: "orange", displayName: "오렌지", swatchHex: "#F2994A"),
        KartColorOption(id: "pink", displayName: "핑크", swatchHex: "#F5A6C6"),
        KartColorOption(id: "purple", displayName: "퍼플", swatchHex: "#8E5FD6"),
        KartColorOption(id: "red", displayName: "레드", swatchHex: "#E8463A"),
        KartColorOption(id: "silver", displayName: "실버", swatchHex: "#C7C9CC"),
        KartColorOption(id: "undyed", displayName: "기본", swatchHex: "#D9D4C7"),
        KartColorOption(id: "white", displayName: "화이트", swatchHex: "#F5F5F5"),
        KartColorOption(id: "yellow", displayName: "옐로우", swatchHex: "#F4D03F"),
    ]

    static let karts: [KartModel] = [
        KartModel(id: "arcrix", displayName: "Arcrix", usdzResourceName: "arcrix", colorOptions: standardColors),
        KartModel(id: "bogubkart", displayName: "Bogub Kart", usdzResourceName: "bogubkart", colorOptions: standardColors),
        KartModel(id: "gospel", displayName: "Gospel", usdzResourceName: "gospel", colorOptions: standardColors),
        KartModel(id: "razr", displayName: "Razr", usdzResourceName: "razr", colorOptions: standardColors),
        KartModel(id: "sirius", displayName: "Sirius", usdzResourceName: "sirius", colorOptions: standardColors),
        KartModel(id: "mms", displayName: "MMS", usdzResourceName: "mms", colorOptions: []),
    ]
}
