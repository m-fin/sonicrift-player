#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

enum DSPMath {
    static func sin(_ x: Double) -> Double {
        DarwinSin(x)
    }

    static func tanh(_ x: Double) -> Double {
        DarwinTanh(x)
    }

    static func exp(_ x: Double) -> Double {
        DarwinExp(x)
    }

    static func floor(_ x: Double) -> Double {
        DarwinFloor(x)
    }

    static func power(_ base: Double, _ exponent: Double) -> Double {
        DarwinPow(base, exponent)
    }

    /// Odd saturation used on chord voices. Harmonics stay above the voice.
    static func warmSaturate(_ x: Double, drive: Double) -> Double {
        let safeDrive = max(drive, 0.001)
        let shaped = tanh(x * safeDrive)
        let normal = tanh(safeDrive)
        if normal == 0 { return 0 }
        return shaped / normal
    }
}

private func DarwinSin(_ x: Double) -> Double { sin(x) }
private func DarwinTanh(_ x: Double) -> Double { tanh(x) }
private func DarwinExp(_ x: Double) -> Double { exp(x) }
private func DarwinFloor(_ x: Double) -> Double { floor(x) }
private func DarwinPow(_ base: Double, _ exponent: Double) -> Double { pow(base, exponent) }
