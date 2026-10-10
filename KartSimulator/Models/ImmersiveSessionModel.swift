import Observation

/// "박스 열기/닫기" 상태를 창(`ContentView`)과 이머시브 공간(`ImmersiveBoxView`)이 함께 본다.
/// 각자 따로 `@State`로 들고 있으면, 이머시브 공간 안에서 닫았을 때 창의 버튼 라벨이
/// "박스 닫기"로 어긋난 채 남는다.
@Observable
final class ImmersiveSessionModel {
    var isOpen = false
}
