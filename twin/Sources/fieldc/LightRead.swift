import FieldCore
import FieldGPU
import Foundation

// Reading the field with light (ENGINE.md, "scan and reading"). Sound changes
// the air's refractive index (n − 1 is proportional to the density, which
// follows the pressure adiabatically), so a laser crossing the chamber picks
// up a phase
//     Δφ(y, z) = k_L (n₀ − 1)/(γ P₀) ∫ p(x, y, z) dx
// along its path. Strobed at a tone (a lock-in at that frequency), a camera
// behind a schlieren or interferometer sees the complex line integral of that
// tone's pressure. That is how the machine can measure its own field — the
// real response of the real plates, which calibrates the twin — and it is a
// rendering of the field for the screen. n₀ − 1 = 2.7e-4 at 633 nm, γ = 1.4,
// P₀ = 101 325 Pa.

struct LightView {
    var n: Int                 // pixels per side (y across, z up)
    var spacing: Double        // m
    var halfWidth: Double      // m
    /// rms over tones of |Δφ_f| (rad), [k · n + j].
    var amplitude: [Double]
    var peak: Double { amplitude.max() ?? 0 }
}

/// The view along x through the plate array's field for compiled drives at
/// drive power `power` (Σ|v|², (m/s)²): rays every `spacing` over ±halfWidth
/// in y and z around `centre`, each integrated over ±pathHalfLength in x
/// (samples every λ/4 at the highest tone).
func lightView(field: ArrayFieldGPU, drives: [[Complex]], power: Double, centre: Vec3,
               halfWidth: Double, spacing: Double, pathHalfLength: Double) throws -> LightView {
    let n = Int((2 * halfWidth / spacing).rounded()) + 1
    let coef = (2 * Double.pi / 633e-9) * 2.7e-4 / (1.4 * 101_325)
    let dx = field.medium.wavelength(at: field.frequencies.max()!) / 4
    let nx = Int((2 * pathHalfLength / dx).rounded()) + 1
    let rays = n * n
    var acc = [Double](repeating: 0, count: rays)
    let scale = power.squareRoot() * coef * dx
    let raysPerBatch = max(1, 200_000 / nx)
    for t in 0..<field.toneCount {
        var r0 = 0
        while r0 < rays {
            let r1 = min(rays, r0 + raysPerBatch)
            var pts: [SIMD4<Float>] = []
            pts.reserveCapacity((r1 - r0) * nx)
            for r in r0..<r1 {
                let j = r % n, k = r / n
                let y = centre.y - halfWidth + Double(j) * spacing, z = centre.z - halfWidth + Double(k) * spacing
                for i in 0..<nx {
                    let x = centre.x - pathHalfLength + Double(i) * dx
                    pts.append(SIMD4(Float(x), Float(y), Float(z), 0))
                }
            }
            let S = try field.fields(drives[t], tone: t, points: pts)
            for r in r0..<r1 {
                var sum = Complex.zero
                let base = (r - r0) * nx
                for i in 0..<nx {
                    let w = (i == 0 || i == nx - 1) ? 0.5 : 1.0          // trapezoid
                    sum += S[(base + i) * 4] * w
                }
                acc[r] += (sum * scale).magnitudeSquared
            }
            r0 = r1
        }
    }
    return LightView(n: n, spacing: spacing, halfWidth: halfWidth, amplitude: acc.map { $0.squareRoot() })
}
