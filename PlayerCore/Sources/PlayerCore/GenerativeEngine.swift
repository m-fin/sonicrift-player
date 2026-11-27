import Foundation

public enum GenerativePreset: String, CaseIterable, Codable, Sendable, Identifiable, Equatable {
    case deepFocus = "deep-focus"
    case warmDrift = "warm-drift"
    case nightDrive = "night-drive"
    case sleepHalo = "sleep-halo"
    case microtonalBloom = "microtonal-bloom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepFocus: return "Deep Focus"
        case .warmDrift: return "Warm Drift"
        case .nightDrive: return "Night Drive"
        case .sleepHalo: return "Sleep Halo"
        case .microtonalBloom: return "Microtonal Bloom"
        }
    }

    public var summary: String {
        switch self {
        case .deepFocus: return "Dorian pads, a still bass, and a slow three-against-four."
        case .warmDrift: return "Lydian harmony that leans warm and a little behind the beat."
        case .nightDrive: return "Minor motion, a low pulse, and headlights on the window."
        case .sleepHalo: return "A major seventh held almost still."
        case .microtonalBloom: return "Seven-limit intervals opening one seed at a time."
        }
    }

    var bassHz: Double {
        switch self {
        case .deepFocus: return 55
        case .warmDrift: return 49
        case .nightDrive: return 41.2
        case .sleepHalo: return 43.65
        case .microtonalBloom: return 50
        }
    }

    var defaultTempo: Double {
        switch self {
        case .deepFocus: return 72
        case .warmDrift: return 66
        case .nightDrive: return 104
        case .sleepHalo: return 48
        case .microtonalBloom: return 80
        }
    }

    var scale: [Double] {
        switch self {
        case .deepFocus: return [1, 9.0 / 8, 6.0 / 5, 4.0 / 3, 3.0 / 2, 5.0 / 3, 16.0 / 9]
        case .warmDrift: return [1, 9.0 / 8, 5.0 / 4, 45.0 / 32, 3.0 / 2, 5.0 / 3, 15.0 / 8]
        case .nightDrive: return [1, 9.0 / 8, 6.0 / 5, 4.0 / 3, 3.0 / 2, 8.0 / 5, 9.0 / 5]
        case .sleepHalo: return [1, 9.0 / 8, 5.0 / 4, 4.0 / 3, 3.0 / 2, 5.0 / 3, 15.0 / 8]
        case .microtonalBloom: return [1, 8.0 / 7, 6.0 / 5, 4.0 / 3, 3.0 / 2, 12.0 / 7, 7.0 / 4]
        }
    }

    var degrees: [Int] {
        switch self {
        case .deepFocus: return [0, 3, 4, 2]
        case .warmDrift: return [0, 3, 4, 1]
        case .nightDrive: return [0, 5, 3, 4]
        case .sleepHalo: return [0, 3, 4, 1]
        case .microtonalBloom: return [0, 3, 2, 5]
        }
    }

    var barsPerChord: Double {
        switch self {
        case .deepFocus: return 4
        case .warmDrift: return 4
        case .nightDrive: return 2
        case .sleepHalo: return 6
        case .microtonalBloom: return 4
        }
    }

    var pulseRatios: [Double] {
        switch self {
        case .deepFocus: return [1, 4.0 / 3]
        case .warmDrift: return [1, 3.0 / 2]
        case .nightDrive: return [1, 3.0 / 2, 2]
        case .sleepHalo: return [0.5, 1.0 / 3]
        case .microtonalBloom: return [1, 5.0 / 4]
        }
    }
}

public struct GenerativeParameters: Equatable, Sendable {
    public var preset: GenerativePreset
    public var seed: UInt64
    public var density: Double
    public var warmth: Double
    public var tempo: Double
    public var drift: Double

    public init(
        preset: GenerativePreset,
        seed: UInt64 = 1,
        density: Double = 0.55,
        warmth: Double = 0.72,
        tempo: Double? = nil,
        drift: Double = 0.28
    ) {
        self.preset = preset
        self.seed = seed == 0 ? 1 : seed
        self.density = Self.clamp(density, 0, 1)
        self.warmth = Self.clamp(warmth, 0, 1)
        self.tempo = Self.clamp(tempo ?? preset.defaultTempo, 36, 180)
        self.drift = Self.clamp(drift, 0, 1)
    }

    public func clamped() -> GenerativeParameters {
        GenerativeParameters(
            preset: preset,
            seed: seed,
            density: density,
            warmth: warmth,
            tempo: tempo,
            drift: drift
        )
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }
}

public struct ChordTone: Equatable, Sendable {
    public var leftHz: Double
    public var rightHz: Double

    public init(leftHz: Double, rightHz: Double) {
        self.leftHz = leftHz
        self.rightHz = rightHz
    }
}

public struct GenerativePatch: Equatable, Sendable {
    public var bassPartials: [Double]
    public var chords: [[ChordTone]]
    public var pulseRatios: [Double]
    public var pulseHz: [Double]
    public var lfoHz: Double
    public var barsPerChord: Double

    public init(
        bassPartials: [Double],
        chords: [[ChordTone]],
        pulseRatios: [Double],
        pulseHz: [Double],
        lfoHz: Double,
        barsPerChord: Double
    ) {
        self.bassPartials = bassPartials
        self.chords = chords
        self.pulseRatios = pulseRatios
        self.pulseHz = pulseHz
        self.lfoHz = lfoHz
        self.barsPerChord = barsPerChord
    }

    public var bassStaysBelow120Hz: Bool {
        !bassPartials.isEmpty && bassPartials.allSatisfy { $0 > 20 && $0 < 120 }
    }

    public static func bassPartials(for preset: GenerativePreset) -> [Double] {
        let fundamental = min(preset.bassHz, 90)
        var partials = [fundamental]
        let second = fundamental * 2
        if second < 118 { partials.append(second) }
        let sub = fundamental / 2
        if sub >= 28 && sub < 118 { partials.append(sub) }
        return partials
    }

    public static func make(preset: GenerativePreset, seed: UInt64) -> GenerativePatch {
        var rng = SplitMix64(state: seed == 0 ? 1 : seed)
        let partials = bassPartials(for: preset)
        let scale = preset.scale
        let root = max(preset.bassHz * 4, 220)
        var chords: [[ChordTone]] = []
        for degree in preset.degrees {
            var tones: [ChordTone] = []
            for offset in [0, 2, 4, 6] {
                let index = degree + offset
                let wrapped = positiveModulo(index, scale.count)
                let octave = Double(index / scale.count)
                let ratio = scale[wrapped] * DSPMath.power(2, octave)
                var freq = root * ratio
                while freq < 220 { freq *= 2 }
                while freq > 960 { freq *= 0.5 }
                let cents = (rng.unit() - 0.5) * 9
                let bend = DSPMath.power(2, cents / 1200)
                let left = max(200, freq / bend)
                let right = max(200, freq * bend)
                tones.append(ChordTone(leftHz: left, rightHz: right))
            }
            chords.append(tones)
        }
        var pulses: [Double] = []
        for _ in preset.pulseRatios {
            pulses.append(420 + rng.unit() * 360)
        }
        return GenerativePatch(
            bassPartials: partials,
            chords: chords,
            pulseRatios: preset.pulseRatios,
            pulseHz: pulses,
            lfoHz: 0.03 + rng.unit() * 0.05,
            barsPerChord: preset.barsPerChord
        )
    }
}

public struct VisualEnergy: Equatable, Sendable {
    public var low: Float
    public var mid: Float
    public var high: Float

    public init(low: Float, mid: Float, high: Float) {
        self.low = low
        self.mid = mid
        self.high = high
    }

    public static let silent = VisualEnergy(low: 0, mid: 0, high: 0)
}

public struct GenerativeBuffer: Equatable, Sendable {
    public var left: [Float]
    public var right: [Float]
    public var bass: [Float]
    public var energy: VisualEnergy

    public init(left: [Float], right: [Float], bass: [Float], energy: VisualEnergy) {
        self.left = left
        self.right = right
        self.bass = bass
        self.energy = energy
    }
}

public enum GenerativeRenderMode: Sendable {
    case full
    case bassOnly
}

public struct GenerativeEngine {
    public private(set) var parameters: GenerativeParameters
    public private(set) var patch: GenerativePatch
    public private(set) var renderedFrames: Int = 0

    private var lowpassL: Double = 0
    private var lowpassR: Double = 0
    private var pulseY: Double = 0
    private var pulseX: Double = 0
    private var highState: Double = 0

    public init(parameters: GenerativeParameters) {
        let clamped = parameters.clamped()
        self.parameters = clamped
        self.patch = GenerativePatch.make(preset: clamped.preset, seed: clamped.seed)
    }

    public mutating func update(_ parameters: GenerativeParameters) {
        let next = parameters.clamped()
        let structuralChange = next.preset != self.parameters.preset || next.seed != self.parameters.seed
        self.parameters = next
        if structuralChange {
            patch = GenerativePatch.make(preset: next.preset, seed: next.seed)
            renderedFrames = 0
            lowpassL = 0
            lowpassR = 0
            pulseY = 0
            pulseX = 0
            highState = 0
        }
    }

    public mutating func render(frameCount: Int, sampleRate: Double, mode: GenerativeRenderMode = .full) -> GenerativeBuffer {
        let count = max(0, frameCount)
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        var bass = [Float](repeating: 0, count: count)
        let energy = render(
            frameCount: count,
            sampleRate: sampleRate,
            mode: mode,
            left: &left,
            right: &right,
            bass: &bass
        )
        return GenerativeBuffer(left: left, right: right, bass: bass, energy: energy)
    }

    public mutating func render(
        frameCount: Int,
        sampleRate: Double,
        mode: GenerativeRenderMode = .full,
        left: inout [Float],
        right: inout [Float],
        bass: inout [Float]
    ) -> VisualEnergy {
        precondition(left.count >= frameCount && right.count >= frameCount && bass.count >= frameCount)
        return left.withUnsafeMutableBufferPointer { leftBuffer in
            right.withUnsafeMutableBufferPointer { rightBuffer in
                bass.withUnsafeMutableBufferPointer { bassBuffer in
                    render(
                        frameCount: frameCount,
                        sampleRate: sampleRate,
                        mode: mode,
                        left: leftBuffer.baseAddress!,
                        right: rightBuffer.baseAddress!,
                        bass: bassBuffer.baseAddress!
                    )
                }
            }
        }
    }

    public mutating func render(
        frameCount: Int,
        sampleRate: Double,
        mode: GenerativeRenderMode = .full,
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>,
        bass: UnsafeMutablePointer<Float>? = nil
    ) -> VisualEnergy {
        let rate = max(sampleRate, 1)
        let dt = 1.0 / rate
        let warmth = parameters.warmth
        let density = parameters.density
        let drive = 1.0 + warmth * 1.6
        let cutoffBase = 700.0 + (1.0 - warmth) * 2800.0
        var lowSum = 0.0
        var midSum = 0.0
        var highSum = 0.0
        let chordCount = max(patch.chords.count, 1)

        for index in 0..<frameCount {
            let frame = renderedFrames + index
            let time = Double(frame) / rate
            let bassSample = bassSample(at: time)
            bass?[index] = Float(bassSample)

            if mode == .bassOnly {
                let value = Float(bassSample)
                left[index] = value
                right[index] = value
                lowSum += abs(bassSample)
                continue
            }

            let lfo = DSPMath.sin(2 * Double.pi * patch.lfoHz * time)
            let driftedTempo = parameters.tempo * (1 + parameters.drift * 0.035 * lfo)
            let beat = time * (driftedTempo / 60)
            let position = beat / max(patch.barsPerChord, 0.25)
            let chordIndex = positiveModulo(Int(DSPMath.floor(position)), chordCount)
            let previousIndex = positiveModulo(chordIndex - 1, chordCount)
            let fraction = position - DSPMath.floor(position)
            let blend = min(1, fraction / 0.22)
            let fade = frame < Int(rate * 0.05) ? Double(frame) / (rate * 0.05) : 1

            var midL = 0.0
            var midR = 0.0
            mixChord(patch.chords[chordIndex], time: time, drive: drive, gain: blend, intoLeft: &midL, intoRight: &midR)
            mixChord(patch.chords[previousIndex], time: time, drive: drive, gain: 1 - blend, intoLeft: &midL, intoRight: &midR)
            if density > 0 {
                let shimmer = density * 0.35
                mixChord(patch.chords[chordIndex], time: time, drive: drive, gain: blend * shimmer, octave: 2, intoLeft: &midL, intoRight: &midR)
            }
            midL *= fade
            midR *= fade

            let cutoff = cutoffBase * (1 + parameters.drift * 0.22 * lfo)
            let alpha = 1 - DSPMath.exp(-2 * Double.pi * cutoff * dt)
            lowpassL += alpha * (midL - lowpassL)
            lowpassR += alpha * (midR - lowpassR)

            let pulse = highpassedPulse(at: time, sampleInterval: dt) * density
            let leftSample = bassSample + lowpassL + pulse
            let rightSample = bassSample + lowpassR + pulse
            left[index] = Float(leftSample)
            right[index] = Float(rightSample)
            lowSum += abs(bassSample)
            let mid = 0.5 * (lowpassL + lowpassR)
            midSum += abs(mid)
            let high = mid - highState
            highState += 0.08 * (mid - highState)
            highSum += abs(high)
        }

        renderedFrames += frameCount
        let divisor = Double(max(frameCount, 1))
        return VisualEnergy(
            low: Float(lowSum / divisor),
            mid: Float(midSum / divisor),
            high: Float(highSum / divisor)
        )
    }

    private func bassSample(at time: Double) -> Double {
        var sum = 0.0
        var weight = 0.0
        let fundamental = patch.bassPartials.first ?? 55
        for (index, frequency) in patch.bassPartials.enumerated() {
            guard frequency < 120 else { continue }
            let amplitude: Double
            if index == 0 {
                amplitude = 1
            } else if frequency < fundamental {
                amplitude = 0.48
            } else {
                amplitude = 0.2
            }
            sum += amplitude * DSPMath.sin(2 * Double.pi * frequency * time)
            weight += amplitude
        }
        guard weight > 0 else { return 0 }
        return sum / weight * 0.34
    }

    private func mixChord(
        _ tones: [ChordTone],
        time: Double,
        drive: Double,
        gain: Double,
        octave: Double = 1,
        intoLeft left: inout Double,
        intoRight right: inout Double
    ) {
        guard gain > 0 else { return }
        for tone in tones {
            let leftHz = tone.leftHz * octave
            let rightHz = tone.rightHz * octave
            guard leftHz > 140, rightHz > 140 else { continue }
            let rawL = DSPMath.sin(2 * Double.pi * leftHz * time)
            let rawR = DSPMath.sin(2 * Double.pi * rightHz * time)
            left += DSPMath.warmSaturate(rawL, drive: drive) * gain * 0.08
            right += DSPMath.warmSaturate(rawR, drive: drive) * gain * 0.08
        }
    }

    private mutating func highpassedPulse(at time: Double, sampleInterval: Double) -> Double {
        guard !patch.pulseRatios.isEmpty, parameters.tempo > 0 else { return 0 }
        var dry = 0.0
        for (index, ratio) in patch.pulseRatios.enumerated() {
            let period = (60.0 / parameters.tempo) / max(ratio, 0.05)
            let phase = (time / period).truncatingRemainder(dividingBy: 1)
            let envelope = DSPMath.exp(-phase * 16)
            let frequency = patch.pulseHz.indices.contains(index) ? patch.pulseHz[index] : 640
            dry += DSPMath.sin(2 * Double.pi * frequency * time) * envelope
        }
        dry *= 0.03
        let cutoff = 180.0
        let rc = 1.0 / (2 * Double.pi * cutoff)
        let alpha = rc / (rc + sampleInterval)
        pulseY = alpha * (pulseY + dry - pulseX)
        pulseX = dry
        return pulseY
    }
}

public enum SeedSource {
    public static func next(after seed: UInt64) -> UInt64 {
        var rng = SplitMix64(state: seed == 0 ? 1 : seed)
        let value = rng.next()
        return value == 0 ? 1 : value
    }
}

struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / 9007199254740992.0
    }
}

private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
    guard modulus > 0 else { return 0 }
    let remainder = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}
