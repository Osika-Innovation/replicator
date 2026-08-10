import Foundation

/// G5 — the keystone gate: T0 propagator vs T1 FDTD in an empty chamber.
///
/// WHY THIS IS THE MOST IMPORTANT GATE IN THE SET. §5 wires the two solver
/// tiers together "by an acceptance gate rather than by faith": every field
/// slice, trap marker and particle in the viewport is computed by T0, and T0 is
/// a closed-form approximation. Without this comparison the interactive tier is
/// trusted on assertion alone — and if it is wrong, the UI is confidently lying
/// about physics.
///
/// Method:
///  1. Drive a MONOPOLE point source in an FDTD box whose walls are heavily
///     sponged, so the solver approximates free space — which is the regime T0
///     models. Comparing against rigid walls would measure the walls, not the
///     propagator.
///  2. Run past the transient, then extract the complex phasor at every sample
///     point by quadrature correlation over a whole number of periods.
///  3. Fit ONE complex scale factor between the two fields and report the
///     residual. The scale absorbs source-strength and unit conventions, which
///     differ legitimately between a cell injection and a radiating element;
///     everything else — amplitude decay, phase, geometry — is under test.
public enum G5 {

    public static func run(frequency: Double = 10_000,
                           medium: Medium = .air,
                           cellsPerWavelength: Int = 12,
                           domainWavelengths: Double = 11) -> GateResult {
        let lambda = medium.wavelength(at: frequency)
        let dx = lambda / Double(cellsPerWavelength)
        // Domain and sponge are specified in WAVELENGTHS, not cells, so that
        // refining the grid is a genuine convergence test. With a fixed cell
        // count, refining shrinks the physical domain and the sample annulus
        // moves toward the source and the sponge — which made a resolution
        // sweep read non-monotonically (0.130 at lambda/8, 0.042 at lambda/12,
        // but 0.076 at lambda/16) and would have been misread as the propagator
        // failing at high resolution.
        let n = max(48, Int((domainWavelengths * Double(cellsPerWavelength)).rounded()))
        let spongeCells = max(8, Int((1.5 * Double(cellsPerWavelength)).rounded()))
        let sim = FDTD(nx: n, ny: n, nz: n, dx: dx, medium: medium,
                       spongeCells: spongeCells)
        let c = n / 2
        let srcPos = Vec3(Double(c) * dx, Double(c) * dx, Double(c) * dx)

        // Sample ring: far enough from the source to be past the near field,
        // and inside the sponge margin so we measure free-field propagation.
        let inner = 1.5 * lambda
        let outer = Double(n / 2 - spongeCells - 4) * dx
        guard outer > inner else {
            return GateResult(id: "G5", name: "T0 vs T1 (empty chamber)",
                              measured: .infinity, threshold: 0.05,
                              detail: "domain too small for a valid sample region")
        }
        var samples: [(Vec3, Int, Int, Int)] = []
        var seed: UInt64 = 0x6155
        func rnd() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 11) & 0xFFFFFFF) / Double(0xFFFFFFF)
        }
        while samples.count < 160 {
            let i = Int(rnd() * Double(n)), j = Int(rnd() * Double(n)), k = Int(rnd() * Double(n))
            guard i > 1, j > 1, k > 1, i < n - 2, j < n - 2, k < n - 2 else { continue }
            let p = Vec3(Double(i) * dx, Double(j) * dx, Double(k) * dx)
            let r = (p - srcPos).length
            guard r >= inner, r <= outer else { continue }
            samples.append((p, i, j, k))
        }

        // --- T1: drive continuously, run past the transient, extract phasors ---
        let omega = 2 * Double.pi * frequency
        let period = 1.0 / frequency
        let stepsPerPeriod = Int((period / sim.dt).rounded())
        // The wavefront must cross the domain (110 cells / 8 per wavelength
        // = 13.75 lambda, so ~14 periods) and its reflections be absorbed
        // before the field is stationary.
        let settle = stepsPerPeriod * 22
        let measure = stepsPerPeriod * 10       // whole periods only
        var accCos = [Double](repeating: 0, count: samples.count)
        var accSin = [Double](repeating: 0, count: samples.count)

        for step in 0..<(settle + measure) {
            let t = Double(step) * sim.dt
            // Ramp the source on smoothly; a hard start rings the grid.
            let ramp = min(1.0, t / (8 * period))
            sim.addPressure(ramp * sin(omega * t), at: c, c, c)
            sim.advance()
            guard step >= settle else { continue }
            let tm = Double(step + 1) * sim.dt
            for (idx, s) in samples.enumerated() {
                let p = sim.pressure(at: s.1, s.2, s.3)
                accCos[idx] += p * cos(omega * tm)
                accSin[idx] += p * sin(omega * tm)
            }
        }
        let norm = 2.0 / Double(measure)
        // TIME CONVENTION, and it is not cosmetic. T0 writes outgoing waves as
        // exp(+ikr), which is outgoing only under exp(-i w t). So the phasor P
        // must satisfy p(t) = Re{P exp(-i w t)}, giving P = a + i b for
        // p(t) = a cos(wt) + b sin(wt).
        //
        // Getting this backwards (P = a - i b) pairs exp(+ikr) with exp(+i w t),
        // i.e. compares an outgoing wave against an INCOMING one. The two then
        // differ by a phase of 2kr that varies with distance, so no single
        // complex scale can align them and the residual pins at ~1.0 — which is
        // exactly what the first run reported (0.9889).
        let t1 = (0..<samples.count).map {
            Complex(accCos[$0] * norm, accSin[$0] * norm)
        }

        // --- T0: the same monopole, evaluated at the same points ---
        let element = Element(position: srcPos, normal: Vec3(0, 0, 1),
                              area: dx * dx, surface: .panel, gateIndex: 0,
                              directivity: .monopole)
        let lat = FieldLattice(origin: .zero, spacing: dx, nx: 1, ny: 1, nz: 1)
        let prop = Propagator(elements: [element], lattice: lat,
                              frequency: frequency, medium: medium, gateCount: 1)
        let t0 = samples.map { prop.pressure(at: $0.0, drive: [Complex(1, 0)]) }

        // --- one complex scale, then the residual ---
        var num = Complex.zero
        var den = 0.0
        for i in t0.indices {
            num += t0[i].conjugate * t1[i]
            den += t0[i].magnitudeSquared
        }
        guard den > 0 else {
            return GateResult(id: "G5", name: "T0 vs T1 (empty chamber)",
                              measured: .infinity, threshold: 0.05,
                              detail: "T0 field is identically zero")
        }
        let alpha = num / den
        let scaled = t0.map { $0 * alpha }
        let rel = scaled.relativeL2(to: t1)

        return GateResult(
            id: "G5", name: "T0 propagator vs T1 FDTD (empty chamber)",
            measured: rel, threshold: 0.05,
            detail: "\(samples.count) points, \(String(format: "%.1f", inner / lambda))"
                  + "–\(String(format: "%.1f", outer / lambda)) lambda from source; "
                  + "\(frequency / 1000) kHz, dx = lambda/\(cellsPerWavelength), "
                  + "\(n)^3 cells; "
                  + "one complex scale fitted (|a| = "
                  + "\(String(format: "%.3g", alpha.magnitude)))")
    }
}
