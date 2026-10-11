import Observation

/// "박스 열기/닫기" 상태를 창(`ContentView`)과 이머시브 공간(`ImmersiveBoxView`)이 함께 본다.
/// 각자 따로 `@State`로 들고 있으면, 이머시브 공간 안에서 닫았을 때 창의 버튼 라벨이
/// "박스 닫기"로 어긋난 채 남는다.
@Observable
final class ImmersiveSessionModel {
    var isOpen = false
    /// 3인칭에 들어가면서 메뉴 창을 `dismissWindow`로 숨겼는지(Issue #27). `WindowGroup`은 `openWindow`마다 새 창을
    /// 만들기 때문에, 우리가 숨긴 경우에만 다시 연다.
    var menuWindowHidden = false
}
