import PlayerCore
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var showSource = false

    var body: some View {
        NavigationStack {
            StudioScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        if let status = model.statusMessage {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(Studio.muted)
                        }
                        section("Latest Drops", tracks: LibraryBrowser.latestDrops(in: model.visibleTracks, now: Date()), empty: "Nothing new in the last three weeks.")
                        albums
                        section("Favorites", tracks: LibraryBrowser.favorites(model.visibleTracks, store: model.favorites), empty: "Hearts you mark show up here.")
                        downloaded
                        section("Catalog", tracks: model.visibleTracks, empty: "The catalog is empty.")
                        about
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.offlineOnly.toggle()
                        Haptics.tap()
                    } label: {
                        Image(systemName: model.offlineOnly ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    .accessibilityLabel(model.offlineOnly ? "Showing on-device audio" : "Show on-device audio only")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSource = true
                    } label: {
                        Image(systemName: "link")
                    }
                    .accessibilityLabel("Catalog source")
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showSource) {
                CatalogSourceSheet()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Matthew Finley")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Studio.text)
            Text("Music Player")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Studio.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var albums: some View {
        let groups = LibraryBrowser.albums(in: model.visibleTracks).filter { $0.title != LibraryBrowser.singlesTitle }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Albums")
            if groups.isEmpty {
                EmptyNote(text: "Albums appear when a release has a name.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(groups) { group in
                            Button {
                                model.play(group.tracks[0], in: group.tracks)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverArt(title: group.title, artworkURL: group.tracks.first?.artworkURL, size: 148)
                                    Text(group.title)
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(Studio.text)
                                        .lineLimit(1)
                                    Text("\(group.tracks.count) tracks")
                                        .font(.caption)
                                        .foregroundStyle(Studio.muted)
                                }
                                .frame(width: 148, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var downloaded: some View {
        let tracks = LibraryBrowser.onDevice(model.visibleTracks, cache: model.cache)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Downloaded", actionTitle: model.cache.records.isEmpty ? nil : "Remove all") {
                model.removeAllDownloads()
            }
            Text(model.cache.records.isEmpty ? "Bundled demos are already on this iPhone." : "Saved audio uses \(model.formattedCacheSize()).")
                .font(.caption)
                .foregroundStyle(Studio.muted)
            if tracks.isEmpty {
                EmptyNote(text: "Nothing is stored on this iPhone yet.")
            } else {
                ForEach(tracks) { track in
                    TrackRow(track: track, collection: tracks)
                }
            }
        }
    }

    private func section(_ title: String, tracks: [Track], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: title, actionTitle: tracks.contains(where: { RemoteAudio.downloadURL(for: $0) != nil }) ? "Download" : nil) {
                model.download(tracks: tracks, playlistID: title)
            }
            if tracks.isEmpty {
                EmptyNote(text: empty)
            } else {
                ForEach(tracks) { track in
                    TrackRow(track: track, collection: tracks)
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matthew Finley writes electronic pieces and long ambient loops, often made with code. Original demos are on this iPhone, and the public catalog fills in when a connection is available.")
                .font(.footnote)
                .foregroundStyle(Studio.muted)
            Link(destination: CatalogEndpoints.soundCloudProfileURL) {
                Label("SoundCloud", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Studio.amber)
            }
            Text("Music © 2026 Matthew Finley. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(Studio.muted)
        }
        .padding(.top, 8)
    }
}

struct CatalogSourceSheet: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Point this at an HTTPS JSON file using the matthewfinley.tracks/v1 schema. Leave the default if you don't have one yet. The player still opens with the on-device demos.")
                    .font(.footnote)
                    .foregroundStyle(Studio.muted)
                TextField("https://", text: $model.manifestURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(Studio.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Studio.text)
                Spacer()
            }
            .padding(20)
            .background(Studio.background.ignoresSafeArea())
            .navigationTitle("Catalog source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.saveManifestURL()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
