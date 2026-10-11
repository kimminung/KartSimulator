import SwiftUI

@main
struct MyApp: App {
    @State private var kartSelection = KartSelectionModel()
    @State private var immersiveSession = ImmersiveSessionModel()
    #if os(visionOS)
    @State private var immersionStyle: ImmersionStyle = .progressive
    #endif

    var body: some Scene {
        WindowGroup(id: AppScene.menuWindowID) {
            ContentView()
                .environment(kartSelection)
                .environment(immersiveSession)
        }

        #if os(visionOS)
        ImmersiveSpace(id: AppScene.immersiveSpaceID) {
            ImmersiveBoxView()
                .environment(kartSelection)
                .environment(immersiveSession)
        }
        .immersionStyle(selection: $immersionStyle, in: .progressive)
        #endif
    }
}
