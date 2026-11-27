import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
            MoodsView()
                .tabItem { Label("Moods", systemImage: "moon.stars") }
            GenerativeView()
                .tabItem { Label("Generative", systemImage: "waveform") }
            QueueView()
                .tabItem { Label("Queue", systemImage: "list.number") }
        }
        .tint(Studio.amber)
        .sheet(isPresented: $model.showNowPlaying) {
            NowPlayingView()
                .environmentObject(model)
        }
    }
}
