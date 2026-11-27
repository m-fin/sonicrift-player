import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public enum SpectrumMath {
    /// Power of one DFT bin via Goertzel. `frequency` should sit on a bin for a pure sine.
    public static func goertzelPower(_ samples: [Float], frequency: Double, sampleRate: Double) -> Double {
        let count = samples.count
        guard count > 1, frequency > 0, sampleRate > 0 else { return 0 }
        let k = frequency * Double(count) / sampleRate
        let coefficient = 2 * DarwinCos(2 * Double.pi * k / Double(count))
        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0
        for sample in samples {
            s0 = Double(sample) + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        return s1 * s1 + s2 * s2 - coefficient * s1 * s2
    }

    /// Sum of Goertzel power for bins whose center frequency lies in `[minHz, maxHz)`.
    public static func bandPower(_ samples: [Float], sampleRate: Double, minHz: Double, maxHz: Double) -> Double {
        let count = samples.count
        guard count > 8, maxHz > minHz, sampleRate > 0 else { return 0 }
        let resolution = sampleRate / Double(count)
        let first = max(1, Int((minHz / resolution).rounded(.up)))
        let last = min(count / 2 - 1, Int((maxHz / resolution).rounded(.down)))
        guard last >= first else { return 0 }
        var total = 0.0
        for bin in first...last {
            let frequency = Double(bin) * resolution
            total += goertzelPower(samples, frequency: frequency, sampleRate: sampleRate)
        }
        return total
    }
}

private func DarwinCos(_ x: Double) -> Double {
    #if canImport(Darwin)
    return cos(x)
    #elseif canImport(Glibc)
    return cos(x)
    #elseif canImport(Musl)
    return cos(x)
    #else
    return 0
    #endif
}
