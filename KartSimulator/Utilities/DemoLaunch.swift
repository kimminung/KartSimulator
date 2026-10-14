import Foundation

/// 촬영·데모용 실행 인자(결정 66). 시뮬레이터는 손 입력이 없어 README 캡처를 찍으려면 앱이 스스로 박스를 열고 달려야 한다.
/// `xcrun simctl launch <udid> <bundle> -demoTrack circuit_02 -demoMode thirdPerson -demoAutopilot 1` 처럼 넘기면
/// `UserDefaults`에 들어온다(Xcode 스킴 인자도 같음). DEBUG 빌드에서만 읽는다.
enum DemoLaunch {
    static var trackID: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoTrack")
        #else
        return nil
        #endif
    }

    /// "diorama" | "thirdPerson"
    static var modeName: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoMode")
        #else
        return nil
        #endif
    }

    static var autopilot: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "demoAutopilot")
        #else
        return false
        #endif
    }

    static var isActive: Bool { trackID != nil }
}
