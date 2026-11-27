import PlayerCore
import SwiftUI

struct CoverArt: View {
    var title: String
    var artworkURL: String?
    var systemImage: String = "waveform"
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(gradient)
            if let artworkURL, let url = URL(string: artworkURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        mark
                    }
                }
            } else {
                mark
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var corner: CGFloat { size * 0.18 }

    private var mark: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.34, weight: .light))
            .foregroundStyle(Studio.gold.opacity(0.92))
    }

    private var gradient: LinearGradient {
        let palettes: [(Color, Color)] = [
            (Color(red: 0.45, green: 0.24, blue: 0.08), Color(red: 0.16, green: 0.09, blue: 0.05)),
            (Color(red: 0.55, green: 0.32, blue: 0.12), Color(red: 0.12, green: 0.08, blue: 0.06)),
            (Color(red: 0.36, green: 0.22, blue: 0.10), Color(red: 0.10, green: 0.08, blue: 0.07)),
            (Color(red: 0.62, green: 0.40, blue: 0.16), Color(red: 0.18, green: 0.10, blue: 0.06)),
        ]
        let index = abs(title.hashValue) % palettes.count
        let pair = palettes[index]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct TrackRow: View {
    @EnvironmentObject private var model: PlayerModel
    var track: Track
    var collection: [Track]

    var body: some View {
        HStack(spacing: 12) {
            CoverArt(title: track.title, artworkURL: track.artworkURL, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(model.session.trackID == track.id && model.session.route == .catalog ? Studio.amber : Studio.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Studio.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                model.toggleDownload(track)
            } label: {
                Image(systemName: downloadSymbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(downloaded ? Studio.amber : Studio.muted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(downloaded ? "Remove download" : "Download")
            Button {
                Haptics.tap()
                model.toggleFavorite(track.id)
            } label: {
                Image(systemName: model.favorites.contains(track.id) ? "heart.fill" : "heart")
                    .font(.body.weight(.medium))
                    .foregroundStyle(model.favorites.contains(track.id) ? Studio.amber : Studio.muted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(model.favorites.contains(track.id) ? "Remove favorite" : "Favorite")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            model.play(track, in: collection)
        }
    }

    private var downloaded: Bool {
        LibraryBrowser.isOnDevice(track, cache: model.cache)
    }

    private var downloadSymbol: String {
        if model.downloading.contains(track.id) { return "arrow.down.circle" }
        if track.isBundled { return "internaldrive" }
        if model.cache.contains(track.id) { return "checkmark.circle.fill" }
        return "arrow.down.circle"
    }

    private var subtitle: String {
        var parts = [track.artist]
        if let album = track.album, !album.isEmpty { parts.append(album) }
        if let duration = track.durationMs {
            parts.append(Studio.clock(Double(duration) / 1000))
        }
        return parts.joined(separator: " · ")
    }
}

struct SectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Studio.text)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Studio.amber)
            }
        }
    }
}

struct EmptyNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Studio.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

struct MiniPlayerBar: View {
    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        if model.showsMiniPlayer {
            Button {
                model.showNowPlaying = true
            } label: {
                HStack(spacing: 12) {
                    CoverArt(
                        title: model.nowTitle,
                        artworkURL: model.currentTrack?.artworkURL,
                        systemImage: model.session.route == .generative ? "waveform" : "music.note",
                        size: 46
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.nowTitle)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Studio.text)
                            .lineLimit(1)
                        Text(model.nowSubtitle)
                            .font(.caption)
                            .foregroundStyle(Studio.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Haptics.tap()
                        model.togglePlay()
                    } label: {
                        Image(systemName: model.session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(Studio.gold)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Studio.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Studio.line, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Now playing, \(model.nowTitle)")
        }
    }
}
