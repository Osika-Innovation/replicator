import Foundation

/// The force-level trap gate, and the broadband + walled channel-count study.
///
/// Motivation, recorded because it corrects an earlier finding of this program.
/// A first pass measured "RH-1's 24 channels give 10.8x focusing gain vs 18.0x
/// for a 512-channel array" and nearly shipped it to the hardware lane. That
/// number came from a model that assumed away three of the machine's designed-in
/// precision levers:
///
///   1. FREE FIELD vs CAVITY. Rayleigh-Sommerfeld is open air. RH-1 is a closed
///      high-Q cavity, where focusing through multipath makes the *cavity* the
///      aperture and controllable DOF scale with time-bandwidth, not channel
///      count.
///   2. MONOCHROMATIC vs BROADBAND. The panels' printed holograms steer by
///      frequency, so a chord is 24 DOF *per tone* with a different aperture per
///      tone — not the same 24 DOF louder.
///   3. PRESSURE SPOT vs FORCE. The deliverable is force on an object. For
///      well-separated tones the cross terms time-average out, so per-tone
///      Gor'kov potentials ADD: co-locate the main lobes and the sidelobes land
///      in different places and average down.
///
/// So the monochromatic free-field pressure sidelobe (-7.6 to -9.1 dB) is NOT
/// the machine's parasitic-trap floor, and a channel-count verdict drawn from it
/// would mislead. This file measures the thing that actually matters.
public enum BroadbandGate {

    /// Multi-tone Gor'kov potential on a lattice. Per-tone potentials add
    /// because the cross terms time-average to zero for well-separated tones.
    public static func chordPotential(preset: MachinePreset,
                                      tones: [Double],
                                      target: Vec3,
                                      lattice: FieldLattice,
                                      particle: ParticleMaterial,
                                      walls: Propagator.Walls,
                                      useRainbow: Bool,
                                      panelHeight: Double) -> [Double] {
        var U = [Double](repeating: 0, count: lattice.count)
        let map = RainbowMap()
        for f in tones {
            let w = useRainbow
                ? preset.rainbowWeights(frequency: f, map: map, panelHeight: panelHeight)
                : nil
            let prop = Propagator(elements: preset.elements, lattice: lattice,
                                  frequency: f, medium: preset.medium,
                                  gateCount: preset.gateCount,
                                  elementWeights: w, walls: walls)
            let drive = InverseSolver.solve(
                propagator: prop,
                points: [.init(position: target, targetAmplitude: 1)],
                method: .gspat, iterations: 60)
            let g = Gorkov(medium: preset.medium, particle: particle)
            // Use the CACHED operator for pressure, then get velocity by
            // differencing p ON THE LATTICE: v = (i/(omega rho)) grad p.
            // Calling the point evaluators per lattice point re-walks every
            // element and image source and made this study minutes-per-condition.
            let field = prop.forward(drive)
            let peak = field.map(\.magnitude).max() ?? 1
            let scale = peak > 0 ? 1 / peak : 1
            let omega = 2 * Double.pi * f
            let coef = 1.0 / (omega * preset.medium.density * lattice.spacing * 2)
            for k in 0..<lattice.nz {
                for j in 0..<lattice.ny {
                    for i in 0..<lattice.nx {
                        let n = lattice.index(i, j, k)
                        let p = field[n] * scale
                        func d(_ a: Int, _ b: Int, _ c: Int,
                               _ a2: Int, _ b2: Int, _ c2: Int) -> Complex {
                            let lo = lattice.index(max(0, a), max(0, b), max(0, c))
                            let hi = lattice.index(min(lattice.nx - 1, a2),
                                                   min(lattice.ny - 1, b2),
                                                   min(lattice.nz - 1, c2))
                            return (field[hi] - field[lo]) * scale
                        }
                        let gx = d(i-1, j, k, i+1, j, k)
                        let gy = d(i, j-1, k, i, j+1, k)
                        let gz = d(i, j, k-1, i, j, k+1)
                        // multiply by i and by coef
                        let vx = Complex(-gx.im, gx.re) * coef
                        let vy = Complex(-gy.im, gy.re) * coef
                        let vz = Complex(-gz.im, gz.re) * coef
                        U[n] += g.potential(p: p, v: (vx, vy, vz))
                    }
                }
            }
        }
        return U
    }

    /// Parasitic-to-main trap depth ratio: the real figure of merit.
    ///
    /// A trap is a local MINIMUM of U for a positive-contrast particle. Depth is
    /// measured from the local barrier. Parasitic traps are what grab stray
    /// powder, so the number that matters is how deep the best competitor is
    /// relative to the intended trap — not how bright a pressure sidelobe is.
    public static func trapDepthRatio(U: [Double], lattice: FieldLattice,
                                      target: Vec3) -> (ratio: Double,
                                                        mainDepth: Double,
                                                        parasiticDepth: Double) {
        let uMax = U.max() ?? 0
        var minima: [(Int, Double)] = []
        for k in 1..<(lattice.nz - 1) {
            for j in 1..<(lattice.ny - 1) {
                for i in 1..<(lattice.nx - 1) {
                    let n = lattice.index(i, j, k)
                    let u = U[n]
                    var isMin = true
                    for (a, b, c) in [(i-1,j,k),(i+1,j,k),(i,j-1,k),
                                      (i,j+1,k),(i,j,k-1),(i,j,k+1)] {
                        if U[lattice.index(a, b, c)] <= u { isMin = false; break }
                    }
                    if isMin { minima.append((n, uMax - u)) }
                }
            }
        }
        guard !minima.isEmpty else { return (1, 0, 0) }
        // The intended trap is the deepest minimum near the target.
        var mainIdx = -1, mainDepth = -Double.infinity
        for (n, depth) in minima {
            let d = (lattice.position(linear: n) - target).length
            if d < 3 * lattice.spacing && depth > mainDepth {
                mainDepth = depth; mainIdx = n
            }
        }
        if mainIdx < 0 {
            // No trap at the target at all — report the global best as parasitic.
            let best = minima.max(by: { $0.1 < $1.1 })!
            return (Double.infinity, 0, best.1)
        }
        var parasitic = 0.0
        for (n, depth) in minima where n != mainIdx {
            let d = (lattice.position(linear: n) - target).length
            if d > 2 * lattice.spacing { parasitic = max(parasitic, depth) }
        }
        return (mainDepth > 0 ? parasitic / mainDepth : .infinity, mainDepth, parasitic)
    }

    /// The 24-vs-512 study, run at EQUAL TIME-BANDWIDTH so the comparison is
    /// fair: the same tone set and the same walls for both apertures.
    public static func channelCountStudy(tones: Int = 5,
                                         withWalls: Bool = true,
                                         withRainbow: Bool = true) -> [GateResult] {
        let band = (25_000.0, 65_000.0)
        let toneList = (0..<tones).map { i -> Double in
            tones == 1 ? (band.0 + band.1) / 2
                       : band.0 + (band.1 - band.0) * Double(i) / Double(tones - 1)
        }
        let particle = ParticleMaterial.pla()

        func run(_ preset: MachinePreset, panelHeight: Double,
                 label: String) -> (Double, Double) {
            let lambda = preset.medium.wavelength(at: (band.0 + band.1) / 2)
            let target = Vec3(0, 0, preset.buildVolume.height / 2)
            // A RESOLVED neighbourhood around the target, not the whole volume.
            // Traps sit lambda/2 apart, so a lattice coarser than ~lambda/6
            // cannot resolve the structure this metric is about — a first pass
            // at 0.9*lambda returned par/main = 1.0 everywhere, which is the
            // metric failing, not the machine.
            let sp = lambda / 6
            let half = 3 * lambda
            let n = Int((2 * half / sp).rounded(.down)) + 1
            let lat = FieldLattice(origin: Vec3(target.x - half, target.y - half,
                                                target.z - half),
                                   spacing: sp, nx: n, ny: n, nz: n)
            let walls = withWalls
                ? Propagator.Walls(capSeparation: preset.buildVolume.height,
                                   order: 3, reflectionCoefficient: 0.9)
                : .none
            let U = chordPotential(preset: preset, tones: toneList, target: target,
                                   lattice: lat, particle: particle, walls: walls,
                                   useRainbow: withRainbow, panelHeight: panelHeight)
            let r = trapDepthRatio(U: U, lattice: lat, target: target)
            return (r.ratio, r.mainDepth)
        }

        // Subsample the panel discretization: this study compares apertures, and
        // element count beyond ~lambda/2 buys accuracy this comparison does not need.
        let rh1Full = RH1.preset(frequency: (band.0 + band.1) / 2)
        let rh1 = MachinePreset(id: rh1Full.id, displayName: rh1Full.displayName,
                                elements: rh1Full.elements.enumerated()
                                    .filter { $0.offset % 6 == 0 }.map(\.element),
                                gateCount: rh1Full.gateCount,
                                buildVolume: rh1Full.buildVolume, medium: rh1Full.medium)
        let dense = TestPresets.denseOpposedArray(
            n: 10, separation: rh1.buildVolume.height,
            frequency: (band.0 + band.1) / 2)

        let (rRatio, rDepth) = run(rh1, panelHeight: rh1.buildVolume.height, label: "RH-1")
        let (dRatio, dDepth) = run(dense, panelHeight: dense.buildVolume.height, label: "dense")

        let cond = withWalls ? (withRainbow ? "walls+chord" : "walls") : "free field"
        return [
            GateResult(id: "G9d",
                       name: "parasitic/main trap depth, RH-1 (\(tones)-tone, \(cond))",
                       measured: rRatio, threshold: 0.5,
                       detail: "main depth \(String(format: "%.3e", rDepth)) J; "
                             + "lower is better; bar is provisional"),
            GateResult(id: "I1",
                       name: "RH-1 vs dense-array trap quality (equal time-bandwidth)",
                       measured: rRatio / max(dRatio, 1e-12), threshold: 0,
                       comparison: .informational,
                       detail: "RH-1 parasitic/main \(String(format: "%.3f", rRatio)) vs "
                             + "dense 200-ch \(String(format: "%.3f", dRatio)); "
                             + "ratio >1 means RH-1 worse. \(tones) tones, \(cond). "
                             + "SUPERSEDES the free-field monochromatic gain "
                             + "comparison, which assumed away cavity multipath, "
                             + "frequency steering and force-level superposition"),
        ]
    }
}
