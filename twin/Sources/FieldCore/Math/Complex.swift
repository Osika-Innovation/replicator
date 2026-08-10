import Foundation

/// Minimal complex arithmetic. Hand-rolled per §8's zero-dependency ruling.
public struct Complex: Equatable, Sendable, Codable {
    public var re: Double
    public var im: Double

    public init(_ re: Double = 0, _ im: Double = 0) { self.re = re; self.im = im }

    public static let zero = Complex(0, 0)
    public static let one = Complex(1, 0)

    /// e^{i·theta}
    public static func expi(_ theta: Double) -> Complex {
        Complex(cos(theta), sin(theta))
    }

    public var magnitude: Double { (re * re + im * im).squareRoot() }
    public var magnitudeSquared: Double { re * re + im * im }
    public var phase: Double { atan2(im, re) }
    public var conjugate: Complex { Complex(re, -im) }

    public static func + (a: Complex, b: Complex) -> Complex { Complex(a.re + b.re, a.im + b.im) }
    public static func - (a: Complex, b: Complex) -> Complex { Complex(a.re - b.re, a.im - b.im) }
    public static func * (a: Complex, b: Complex) -> Complex {
        Complex(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re)
    }
    public static func * (a: Complex, s: Double) -> Complex { Complex(a.re * s, a.im * s) }
    public static func * (s: Double, a: Complex) -> Complex { Complex(a.re * s, a.im * s) }
    public static func / (a: Complex, s: Double) -> Complex { Complex(a.re / s, a.im / s) }
    public static func / (a: Complex, b: Complex) -> Complex {
        let d = b.magnitudeSquared
        return Complex((a.re * b.re + a.im * b.im) / d, (a.im * b.re - a.re * b.im) / d)
    }
    public static func += (a: inout Complex, b: Complex) { a = a + b }
    public static func -= (a: inout Complex, b: Complex) { a = a - b }
    public static prefix func - (a: Complex) -> Complex { Complex(-a.re, -a.im) }
}

extension Array where Element == Complex {
    /// L2 norm of a complex vector.
    public var l2: Double { reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot() }

    /// Relative L2 error of `self` against a reference. Used by most gates.
    public func relativeL2(to reference: [Complex]) -> Double {
        precondition(count == reference.count, "length mismatch")
        var num = 0.0, den = 0.0
        for i in indices {
            num += (self[i] - reference[i]).magnitudeSquared
            den += reference[i].magnitudeSquared
        }
        guard den > 0 else { return num > 0 ? .infinity : 0 }
        return (num / den).squareRoot()
    }
}

extension Array where Element == Double {
    public func relativeL2(to reference: [Double]) -> Double {
        precondition(count == reference.count, "length mismatch")
        var num = 0.0, den = 0.0
        for i in indices {
            let d = self[i] - reference[i]
            num += d * d
            den += reference[i] * reference[i]
        }
        guard den > 0 else { return num > 0 ? .infinity : 0 }
        return (num / den).squareRoot()
    }
}
