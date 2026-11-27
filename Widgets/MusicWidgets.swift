import PlayerCore
import SwiftUI
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    var date: Date
    var snapshot: NowPlayingSnapshot
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), snapshot: .idle())
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(NowPlayingEntry(date: Date(), snapshot: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = NowPlayingEntry(date: Date(), snapshot: load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> NowPlayingSnapshot {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        guard let data = defaults?.data(forKey: NowPlayingSnapshot.defaultsKey),
              let snapshot = try? NowPlayingSnapshot.decode(data) else {
            return .idle()
        }
        return snapshot
    }
}

struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NowPlayingEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium:
                    Color(red: 0.067, green: 0.055, blue: 0.047)
                default:
                    AccessoryWidgetBackground()
                }
            }
            .widgetURL(URL(string: entry.snapshot.deepLink))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.snapshot.isPlaying ? "Playing \(entry.snapshot.title)" : entry.snapshot.title)
        case .accessoryCircular:
            Image(systemName: entry.snapshot.isGenerative ? "waveform" : "music.note")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.snapshot.subtitle)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                mark
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matthew Finley")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.91, green: 0.65, blue: 0.29))
                    Text(entry.snapshot.title)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89))
                        .lineLimit(2)
                    Text(entry.snapshot.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.66, green: 0.58, blue: 0.49))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        default:
            VStack(alignment: .leading, spacing: 8) {
                mark
                    .frame(width: 28, height: 28)
                Spacer(minLength: 0)
                Text(entry.snapshot.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89))
                    .lineLimit(2)
                Text(entry.snapshot.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.66, green: 0.58, blue: 0.49))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mark: some View {
        Image(systemName: entry.snapshot.isGenerative ? "waveform" : "music.note")
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(red: 0.91, green: 0.65, blue: 0.29))
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.matthewfinley.musicplayer.nowplaying", provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("The current track or generative mood.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

@main
struct MusicWidgets: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}
