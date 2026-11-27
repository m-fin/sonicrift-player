import SwiftUI

@main
struct MatthewFinleyMusicPlayerApp: App {
    @StateObject private var model = PlayerModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Studio.amber)
                .onOpenURL { model.handle(url: $0) }
        }
    }
}
