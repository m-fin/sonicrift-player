import PlayerCore
import SwiftUI

struct GenerativeView: View {
    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        NavigationStack {
            StudioScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Generative")
                                .font(.system(size: 34, weight: .semibold, design: .serif))
                                .foregroundStyle(Studio.text)
                            Text(model.generative.preset.summary)
                                .font(.subheadline)
                                .foregroundStyle(Studio.muted)
                        }
                        EnergyVisualizer(energy: model.session.route == .generative ? model.energy : .silent)
                        presetPicker
                        controls
                        Button {
                            Haptics.tap(.medium)
                            model.playGenerative(model.generative.preset, present: true)
                        } label: {
                            Text(model.session.route == .generative && model.session.isPlaying ? "Playing live" : "Play this mood")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Studio.amber, in: Capsule())
                                .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.04))
                        }
                        .buttonStyle(.plain)
                        Button {
                            model.newSeed()
                        } label: {
                            Label("New Seed", systemImage: "dice")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(Studio.gold)
                                .overlay(Capsule().stroke(Studio.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Text("Seed \(model.generative.seed)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Studio.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(GenerativePreset.allCases) { preset in
                Button {
                    Haptics.tap()
                    model.playGenerative(preset)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                                .font(.system(.body, design: .serif))
                            Text(preset.summary)
                                .font(.caption2)
                                .foregroundStyle(Studio.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        if model.generative.preset == preset {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Studio.amber)
                        }
                    }
                    .padding(14)
                    .background(model.generative.preset == preset ? Studio.raised : Studio.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(Studio.text)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            knob("Density", value: model.generative.density, range: 0...1) { model.setDensity($0) }
            knob("Warmth", value: model.generative.warmth, range: 0...1) { model.setWarmth($0) }
            knob("Tempo", value: model.generative.tempo, range: 48...140) { model.setTempo($0) }
            knob("Drift", value: model.generative.drift, range: 0...1) { model.setDrift($0) }
        }
        .padding(16)
        .background(Studio.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func knob(_ title: String, value: Double, range: ClosedRange<Double>, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Studio.gold)
                Spacer()
                Text(title == "Tempo" ? "\(Int(value.rounded()))" : String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Studio.muted)
            }
            Slider(value: Binding(get: { value }, set: set), in: range)
                .tint(Studio.amber)
        }
    }
}

struct EnergyVisualizer: View {
    var energy: VisualEnergy

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Studio.amber : Studio.gold.opacity(0.75))
                    .frame(height: barHeight(index))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.12), value: energy.low)
        .accessibilityHidden(true)
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let weights = [0.9, 0.55, 1.0, 0.4, 0.8, 0.35, 0.65]
        let source: Float
        switch index % 3 {
        case 0: source = energy.low
        case 1: source = energy.mid
        default: source = energy.high
        }
        let level = min(1, CGFloat(source) * 3.2) * weights[index]
        return max(8, 80 * level + 8)
    }
}
