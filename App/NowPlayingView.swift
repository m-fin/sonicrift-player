import PlayerCore
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    CoverArt(
                        title: model.nowTitle,
                        artworkURL: model.currentTrack?.artworkURL,
                        systemImage: model.session.route == .generative ? "waveform" : "music.note",
                        size: 280
                    )
                    .shadow(color: Studio.amber.opacity(0.35), radius: 36, y: 12)
                }
                .padding(.top, 12)
                VStack(spacing: 4) {
                    Text(model.nowTitle)
                        .font(.system(.title2, design: .serif))
                        .foregroundStyle(Studio.text)
                        .multilineTextAlignment(.center)
                    Text(model.nowSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Studio.muted)
                }
                if model.session.route == .generative {
                    EnergyVisualizer(energy: model.energy)
                    Text("Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Studio.amber)
                } else {
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { scrubbing ? scrubValue : model.position },
                                set: { scrubValue = $0 }
                            ),
                            in: 0...max(model.duration, 0.1),
                            onEditingChanged: { editing in
                                scrubbing = editing
                                if !editing { model.seek(to: scrubValue) }
                            }
                        )
                        .tint(Studio.amber)
                        HStack {
                            Text(Studio.clock(scrubbing ? scrubValue : model.position))
                            Spacer()
                            Text(Studio.clock(model.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Studio.muted)
                    }
                }
                HStack(spacing: 28) {
                    control(model.queue.shuffle ? "shuffle" : "shuffle", active: model.queue.shuffle) {
                        model.toggleShuffle()
                    }
                    .opacity(model.session.route == .generative ? 0.35 : 1)
                    .disabled(model.session.route == .generative)
                    control("backward.fill") { model.skipPrevious() }
                    Button {
                        Haptics.tap(.medium)
                        model.togglePlay()
                    } label: {
                        Image(systemName: model.session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.04))
                            .frame(width: 72, height: 72)
                            .background(Studio.amber, in: Circle())
                    }
                    .buttonStyle(.plain)
                    control("forward.fill") { model.skipNext() }
                    control(repeatSymbol, active: model.queue.repeatMode != .off) {
                        model.cycleRepeat()
                    }
                    .opacity(model.session.route == .generative ? 0.35 : 1)
                    .disabled(model.session.route == .generative)
                }
                .foregroundStyle(Studio.gold)
                if model.session.route == .generative {
                    Text(model.generative.preset.summary)
                        .font(.footnote)
                        .foregroundStyle(Studio.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .background(Studio.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationBackground(Studio.background)
    }

    private var repeatSymbol: String {
        switch model.queue.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func control(_ symbol: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(active ? Studio.amber : Studio.gold)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
