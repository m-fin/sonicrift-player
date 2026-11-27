import PlayerCore
import SwiftUI

struct MoodsView: View {
    @EnvironmentObject private var model: PlayerModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            StudioScreen {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Mood.allCases) { mood in
                            NavigationLink(value: mood) {
                                MoodCard(mood: mood, count: LibraryBrowser.tracks(model.visibleTracks, mood: mood).count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Moods")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Mood.self) { mood in
                MoodDetail(mood: mood)
            }
        }
    }
}

struct MoodCard: View {
    var mood: Mood
    var count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Studio.amber)
            Text(mood.rawValue)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Studio.text)
            Text(mood.blurb)
                .font(.caption)
                .foregroundStyle(Studio.muted)
                .lineLimit(3)
            Text(count == 1 ? "1 track" : "\(count) tracks")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Studio.gold)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(16)
        .background(Studio.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var icon: String {
        switch mood {
        case .focus: return "scope"
        case .lateNight: return "moon.stars"
        case .sleep: return "bed.double"
        case .ambient: return "water.waves"
        case .driving: return "car"
        case .electronic: return "bolt"
        }
    }
}

struct MoodDetail: View {
    @EnvironmentObject private var model: PlayerModel
    var mood: Mood

    private var tracks: [Track] {
        LibraryBrowser.tracks(model.visibleTracks, mood: mood)
    }

    var body: some View {
        StudioScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mood.blurb)
                        .font(.subheadline)
                        .foregroundStyle(Studio.muted)
                        .padding(.bottom, 8)
                    SectionHeader(title: "Playlist", actionTitle: tracks.isEmpty ? nil : "Download") {
                        model.download(tracks: tracks, playlistID: "mood:\(mood.rawValue)")
                    }
                    if tracks.isEmpty {
                        EmptyNote(text: "No pieces in this mood yet.")
                    } else {
                        ForEach(tracks) { track in
                            TrackRow(track: track, collection: tracks)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(mood.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
