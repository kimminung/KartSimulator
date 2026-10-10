import SwiftUI

@main
struct MyApp: App {
    @State private var kartSelection = KartSelectionModel()
    #if os(visionOS)
    @State private var immersionStyle: ImmersionStyle = .progressive
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(kartSelection)
        }

        #if os(visionOS)
        ImmersiveSpace(id: AppScene.immersiveSpaceID) {
            ImmersiveBoxView()
                .environment(kartSelection)
        }
        .immersionStyle(selection: $immersionStyle, in: .progressive)
        #endif
    }
}
