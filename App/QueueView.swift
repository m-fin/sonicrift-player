import PlayerCore
import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        NavigationStack {
            StudioScreen {
                List {
                    if let track = model.currentTrack, model.session.route == .catalog {
                        Section("Now") {
                            TrackRow(track: track, collection: model.tracks)
                                .listRowBackground(Studio.surface)
                        }
                    } else if model.session.route == .generative {
                        Section("Now") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.generative.preset.displayName)
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(Studio.text)
                                Text("Live generative · \(ArtistName.display)")
                                    .font(.caption)
                                    .foregroundStyle(Studio.muted)
                            }
                            .listRowBackground(Studio.surface)
                        }
                    }
                    Section("Up Next") {
                        if model.upNext.isEmpty {
                            Text(model.session.route == .generative ? "Generative mode plays until you stop it." : "Nothing is queued after this.")
                                .font(.subheadline)
                                .foregroundStyle(Studio.muted)
                                .listRowBackground(Studio.surface)
                        } else {
                            ForEach(model.upNext) { track in
                                TrackRow(track: track, collection: model.upNext)
                                    .listRowBackground(Studio.surface)
                            }
                            .onDelete(perform: model.removeUpNext)
                            .onMove(perform: model.moveUpNext)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(model.upNext.isEmpty)
                }
            }
        }
    }
}
