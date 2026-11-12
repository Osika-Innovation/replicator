import FieldCore
import FieldGPU
import Foundation

// Holding, carrying and flying one bead between the open-air plates: the
// verbs `levitate`, `carry` and `fly` of Rounds 8–9, on the machine of
// ENGINE.md (two plates of independently driven elements, `PlateArray`)
// instead of the glass cylinder and its six gates. The physics and the gates
// (G-P1, G-P2) are the same; the field is the matrix-free GPU operator
// (`ArrayFieldGPU`), so nothing per element is stored and the solvers are the
// field forms of `ForceCompiler.carryStep` / `moveWell`.

/// ∇U at x on a lattice: central differences, trilinear between nodes; nil
/// within `margin` cells of the edge.
func latticeGradient(_ L: FieldLattice, _ U: [Double], _ x: Vec3, margin: Int = 1) -> Vec3? {
    let hs = L.spacing
    let f = (x - L.origin) / hs
    let i0 = Int(f.x.rounded(.down)), j0 = Int(f.y.rounded(.down)), k0 = Int(f.z.rounded(.down))
    guard i0 >= margin, j0 >= margin, k0 >= margin,
          i0 + 1 + margin < L.nx, j0 + 1 + margin < L.ny, k0 + 1 + margin < L.nz else { return nil }
    let tx = f.x - Double(i0), ty = f.y - Double(j0), tz = f.z - Double(k0)
    var g = Vec3(0, 0, 0)
    for (dk, wz) in [(0, 1 - tz), (1, tz)] { for (dj, wy) in [(0, 1 - ty), (1, ty)] { for (di, wx) in [(0, 1 - tx), (1, tx)] {
        let i = i0 + di, j = j0 + dj, k = k0 + dk
        g = g + Vec3((U[L.index(i + 1, j, k)] - U[L.index(i - 1, j, k)]) / (2 * hs),
                     (U[L.index(i, j + 1, k)] - U[L.index(i, j - 1, k)]) / (2 * hs),
                     (U[L.index(i, j, k + 1)] - U[L.index(i, j, k - 1)]) / (2 * hs)) * (wx * wy * wz)
    } } }
    return g
}

/// The plates, a chord, a probe lattice round the centre and the field on it.
struct PlaceRig {
    let ctx: MetalContext
    let array: PlateArray
    let air = RH1Freestanding.roomAir
    let freqs: [Double]
    let lattice: FieldLattice
    let field: ArrayFieldGPU
    var options = ForceCompiler.Options()
    let lam40: Double
    let particle: ParticleMaterial
    var centre: Vec3 { array.centre }
    /// A trap this unique (deepest rival / target) is carried by moving it alone.
    static let unique = 0.3

    /// - Parameter half: half-width of the probe cube (m); ENGINE.md's work
    ///   volume is ±12 mm.
    init(ctx: MetalContext, array: PlateArray, freqs: [Double], half: Double = 12e-3, particle: ParticleMaterial = .pla()) throws {
        self.particle = particle
        // Resonant elements play the plate's own tones, whatever chord is asked for.
        let freqs = array.tones ?? array.inputs?.frequencies ?? freqs
        self.ctx = ctx; self.array = array; self.freqs = freqs
        lam40 = air.wavelength(at: 40_000)
        let h = air.wavelength(at: freqs.max()!) / 8
        let n = Int((2 * half / h).rounded()) | 1
        let hh = Double(n - 1) / 2 * h
        lattice = FieldLattice(origin: array.centre - Vec3(hh, hh, hh), spacing: h, nx: n, ny: n, nz: n)
        field = try ArrayFieldGPU(ctx: ctx, array: array, frequencies: freqs, medium: air, lattice: lattice)
        if array.toneOf != nil || array.inputs != nil { field.amplitudeCap = 1.25 }   // channels share one drive ceiling
        options.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
        options.perToneStarts = false
    }

    /// Gate G-E1 for a drive at `power` (Σ|g|², (m/s)²): the most any
    /// element is asked for ÷ what it can give.
    func elementGate(_ drives: [[Complex]], power: Double, label: String) -> GateResult {
        let s = power.squareRoot()
        if let m = array.inputs {                                // a body: each input against its own limit
            let ask = drives.flatMap { d in d.indices.map { d[$0].magnitude * s / m.maxDrive[$0] } }.max() ?? 0
            return GateResult(id: "G-E1", name: "input drive (\(label)): the most any input is asked for ÷ its limit", measured: ask, threshold: 1, detail: "\(m.plateOf.count) inputs")
        }
        return ElementGates.drive(amplitudes: drives.map { $0.map { $0.magnitude * s } }, frequencies: freqs,
                                  pistonRadius: { array.pistonRadius($0) }, spec: { e, _ in array.spec(e, medium: air) },
                                  medium: air, label: label)[0]
    }

    var tonesText: String { String(format: "%d tones %.0f–%.0f kHz", freqs.count, freqs.min()! / 1000, freqs.max()! / 1000) }

    func field(on lattice: FieldLattice) throws -> ArrayFieldGPU {
        try ArrayFieldGPU(ctx: ctx, array: array, frequencies: freqs, medium: air, lattice: lattice)
    }

    /// A standing-wave node on x: each plate focused on x by time reversal,
    /// the upper plate half a cycle behind the lower (the classic two-sided
    /// levitator), unit total power over the chord.
    func nodeStart(at x: Vec3) -> [[Complex]] {
        freqs.map { f in
            let r = array.channelRow(array.reference(frequency: f, medium: air).gateGradientRows(at: x).p, frequency: f)
            var g = r.enumerated().map { e, v in v.conjugate * (array.plate(of: e) == 0 ? 1.0 : -1.0) }
            let nrm = g.reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot()
            g = g.map { $0 * (1 / (max(nrm, 1e-300) * Double(freqs.count).squareRoot())) }
            return g
        }
    }

    /// Re-aim a drive from a to b: every element's phase turned by the change
    /// in its path to the point (the ratio of its time-reversal phases at b
    /// and a), amplitudes kept. What a phased array does to move a focus; the
    /// compiled structure of the field moves with it.
    func steer(_ drives: [[Complex]], from a: Vec3, to b: Vec3) -> [[Complex]] {
        freqs.indices.map { t in
            let ref = array.reference(frequency: freqs[t], medium: air)
            let ra = array.channelRow(ref.gateGradientRows(at: a).p, frequency: freqs[t]), rb = array.channelRow(ref.gateGradientRows(at: b).p, frequency: freqs[t])
            return drives[t].indices.map { e in
                let turn = rb[e].conjugate * ra[e]
                let m = turn.magnitude
                return m > 0 ? drives[t][e] * (turn * (1 / m)) : drives[t][e]
            }
        }
    }

    /// One carry step from a to b: steer, then put the well on b (and, if a
    /// rival has grown, push it down) with `carryStep`. The minimal-norm
    /// continuation alone keeps the well on its point but distorts the focus
    /// instead of moving it: 4 % of the depth lost per 0.25 mm, 0.11 of it left
    /// after 10 mm (`fieldc carry`, open air, 2026-11-10).
    func step(_ drives: [[Complex]], from a: Vec3, to b: Vec3, balance: Vec3 = Vec3(0, 0, 0)) -> [[Complex]] {
        ForceCompiler.carryStep(field: field, particle: particle, wavelength: lam40, options: options,
                                drives: steer(drives, from: a, to: b), to: b, balance: balance,
                                rivalsBelow: PlaceRig.unique)
    }

    func evaluate(_ drives: [[Complex]], target: Vec3) -> (ForceCompiler.Result, [Double]) {
        let U = field.potential(drives, particle: particle)
        return (ForceCompiler.evaluate(potential: U, drives: drives, lattice: lattice, target: target,
                                       options: options, wavelength: lam40), U)
    }

    /// Pick up: one well at the lattice's centre node and as few others as
    /// possible (the single-site mold), from the node start.
    func pickUp(iterations: Int = 300) -> ForceCompiler.Result {
        let c = ((lattice.nx - 1) / 2, (lattice.ny - 1) / 2, (lattice.nz - 1) / 2)
        let x = lattice.position(c.0, c.1, c.2)
        let m = ForceCompiler.compileMold(field: field, particle: particle, targets: [c], wavelength: lam40,
                                          options: options, start: nodeStart(at: x), iterations: iterations)
        return evaluate(m.drives, target: x).0
    }

    /// How fast the potential follows a drive switch: the field decays at
    /// α c + (−ln R) c / gap; U ∝ amplitude².
    var settling: Double {
        let alpha = air.absorption(at: 50_000)
        return 0.5 / (alpha * air.soundSpeed + -log(max(array.reflection, 1e-3)) * air.soundSpeed / array.gap)
    }

    var chamberText: String {
        String(format: "open air, 2 × %d elements (Ø%.0f mm, %.0f mm apart, R %.1f)", array.perPlate,
               array.plateRadius * 2000, array.gap * 1000, array.reflection)
    }
}

enum PlaceCommand {
    static func run(_ cmd: String, _ args: [String]) -> Int32 {
        do {
            let ctx = try MetalContext()
            switch cmd {
            case "levitate": return try levitate(ctx, args)
            case "carry": return try carry(ctx, args)
            default: return try fly(ctx, args)
            }
        } catch { print("GPU unavailable: \(error)"); return 2 }
    }

    /// The bead a machine is asked to place: P0's is watched by eye and
    /// camera, so expanded polystyrene; the RH-1's is the spec's PLA bead.
    static func bead(_ a: PlateArray) -> (name: String, material: ParticleMaterial) {
        a.tag.hasPrefix("p0") || a.inputs != nil ? ("Ø1.5 mm EPS", .eps(radius: 0.75e-3)) : ("200 µm PLA", .pla())
    }

    static let spread10 = (0..<10).map { 30_000 + 40_000 * (Double($0) + 0.5) / 10 }

    // MARK: - levitate

    /// How hard must the elements drive to hold a bead against gravity? A
    /// drive entry is an element's face velocity (m/s). Compile the trap, read
    /// the largest upward force its well offers per unit drive power along a
    /// fine vertical line through it, and scale the power until that force
    /// carries the bead's weight.
    static func levitate(_ ctx: MetalContext, _ args: [String]) throws -> Int32 {
        let t0 = Date()
        let arr = plateArray(args)
        let cases: [(String, [Double])] = arr.tones.map { t in
            [(String(format: "the plate's %d tones %.0f–%.0f kHz", t.count, t.min()! / 1000, t.max()! / 1000), t)]
        } ?? [
            ("5-tone chord 30–70 kHz", [30_000.0, 40_000, 50_000, 60_000, 70_000]),
            ("10 tones 32–68 kHz", spread10),
        ]
        // P0 is watched by eye and camera: its bead is expanded polystyrene.
        let beads: [(String, ParticleMaterial)] = (arr.tag.hasPrefix("p0") ? [("EPS Ø1.5 mm", ParticleMaterial.eps(radius: 0.75e-3))] : []) + [
            ("PLA Ø200 µm", .pla()),
            ("aluminium Ø200 µm", ParticleMaterial(density: 2700, soundSpeed: 6320, radius: 100e-6)),
            ("steel Ø200 µm", ParticleMaterial(density: 7850, soundSpeed: 5900, radius: 100e-6)),
        ]
        func dB(_ pAmp: Double) -> Double { 20 * log10(pAmp / 2.squareRoot() / 20e-6) }
        var gates: [GateResult] = []
        print("drive = an element's face velocity amplitude (m/s); plane-wave level ρ0c·u in brackets")
        for (label, freqs) in cases {
            let rig = try PlaceRig(ctx: ctx, array: arr, freqs: freqs)
            let air = rig.air
            let r = rig.pickUp()
            print(String(format: "\n%@; %@: sibling ratio %.2f (%d), well %.2f mm from the point", rig.chamberText, label,
                         r.siblingRatio, r.siblings, r.targetOffset * 1000))
            guard let w = r.targetWell else { print("  no well at the target"); continue }
            // Fine lines through the well: vertical and lateral, ±3 mm at 50 µm.
            let ds = 50e-6, m = 60
            let vert = try rig.field(on: FieldLattice(origin: w - Vec3(0, 0, Double(m) * ds), spacing: ds, nx: 1, ny: 1, nz: 2 * m + 1))
            let side = try rig.field(on: FieldLattice(origin: w - Vec3(Double(m) * ds, 0, 0), spacing: ds, nx: 2 * m + 1, ny: 1, nz: 1))
            // The loudest point of the probe volume at unit power (incoherent over tones).
            var p2 = [Double](repeating: 0, count: rig.lattice.count)
            for t in freqs.indices {
                let f = try rig.field.fields(r.drives[t], tone: t, at: rig.lattice.positions)
                for i in p2.indices { p2[i] += f[i * 4].magnitudeSquared }
            }
            let pmax2 = p2.max() ?? 0
            let gmax = r.drives.flatMap { $0 }.map(\.magnitude).max() ?? 0
            for (bname, bead) in beads {
                let Uz = vert.potential(r.drives, particle: bead), Ux = side.potential(r.drives, particle: bead)
                var fUp = 0.0                                     // max of −dU/dz, N per (m/s)²
                for i in 1..<(Uz.count - 1) { fUp = max(fUp, -(Uz[i + 1] - Uz[i - 1]) / (2 * ds)) }
                let weight = bead.mass() * 9.81
                guard fUp > 0 else { print("  \(bname): the well pushes nowhere upward"); continue }
                let P = weight / fUp                              // required Σ|g|², (m/s)²
                let q = 4                                         // curvature over ±0.2 mm
                let kx = (Ux[m + q] - 2 * Ux[m] + Ux[m - q]) / (Double(q * q) * ds * ds) * P
                let fx = kx > 0 ? (kx / bead.mass()).squareRoot() / (2 * Double.pi) : 0
                let u = gmax * P.squareRoot()                     // hardest-driven element, m/s
                let uRMS = (P / Double(arr.channels * freqs.count)).squareRoot()
                let pPeak = (pmax2 * P).squareRoot()
                print(String(format: "  %-18@ weight %.2e N · needs %5.2f m/s on the hardest element (%3.0f dB), %4.2f m/s rms · field peak %3.0f dB · lateral %3.0f Hz",
                             bname as NSString, weight, u, dB(air.density * air.soundSpeed * u), uRMS, dB(pPeak), fx))
                // The machine is asked to hold PLA; the metals are reported, not required.
                var eg = rig.elementGate(r.drives, power: P, label: "holding \(bname)")
                if !bname.hasPrefix("PLA") {
                    eg = GateResult(id: eg.id, name: eg.name, measured: eg.measured, threshold: 1, comparison: .informational, detail: eg.detail)
                }
                print("    " + eg.line)
                gates.append(eg)
                gates.append(GateResult(id: "LEV", name: "\(arr.tag), \(label): \(bname)", measured: u, threshold: 0,
                                        comparison: .informational,
                                        detail: String(format: "hardest element %.2f m/s (%.0f dB plane-wave), rms %.2f m/s; field peak %.0f dB; lateral %.0f Hz; sibling ratio %.2f",
                                                       u, dB(air.density * air.soundSpeed * u), uRMS, dB(pPeak), fx, r.siblingRatio)))
            }
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "levitate-\(arr.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        return 0
    }

    // MARK: - carry

    struct Carry {
        var rig: PlaceRig
        var pick: ForceCompiler.Result
        var path: [Vec3]
        var drives: [[[Complex]]]
    }

    /// The carry sequence: pick up at the centre, 5 mm up, then 5 mm across,
    /// in 0.25 mm steps, each a `carryStep` from the last drive.
    static func carrySequence(_ ctx: MetalContext, _ args: [String], array: PlateArray? = nil,
                              each: ((Int, Vec3, [[Complex]]) -> Void)? = nil) throws -> Carry? {
        let arr = array ?? plateArray(args)
        let rig = try PlaceRig(ctx: ctx, array: arr, freqs: spread10, particle: bead(arr).material)
        let r0 = rig.pickUp()
        guard let w0 = r0.targetWell else { print("no trap at the start"); return nil }
        let stepLen = 0.25e-3
        var path: [Vec3] = [w0]
        for k in 1...20 { path.append(w0 + Vec3(0, 0, Double(k) * stepLen)) }
        for k in 1...20 { path.append(w0 + Vec3(Double(k) * stepLen, 0, 20 * stepLen)) }
        var drives = [r0.drives]
        for (i, x) in path.enumerated() where i > 0 {
            let g = rig.step(drives.last!, from: path[i - 1], to: x)
            drives.append(g)
            each?(i, x, g)
        }
        return Carry(rig: rig, pick: r0, path: path, drives: drives)
    }

    /// Pick up, carry, place (G-P1): a bead is carried only if, at each step,
    /// the trap sits on its point, moved continuously, the new potential runs
    /// downhill from the old well to the new one, it is still the deepest
    /// well, and it kept at least half its starting depth.
    static func carry(_ ctx: MetalContext, _ args: [String]) throws -> Int32 {
        let t0 = Date()
        let stepLen = 0.25e-3
        var ok = true, worstRatio = 0.0, worstOff = 0.0, notUnique = 0, minDepth = Double.infinity
        let arr = plateArray(args)
        let rig = try PlaceRig(ctx: ctx, array: arr, freqs: spread10, particle: bead(arr).material)
        let r0 = rig.pickUp()
        guard let w0 = r0.targetWell else { print("no trap at the start"); return 1 }
        var prevWell = w0, steps = 0
        let depth0 = r0.targetDepth
        var path: [Vec3] = []
        for k in 1...20 { path.append(w0 + Vec3(0, 0, Double(k) * stepLen)) }
        for k in 1...20 { path.append(w0 + Vec3(Double(k) * stepLen, 0, 20 * stepLen)) }
        print(String(format: "%@; %@; lattice %.2f mm (%d³), path steps 0.25 mm; %@", rig.chamberText, rig.tonesText,
                     rig.lattice.spacing * 1000, rig.lattice.nx, bead(arr).name))
        print(String(format: "picked up: sibling ratio %.2f (%d), well %.2f mm from the centre", r0.siblingRatio,
                     r0.siblings, r0.targetOffset * 1000))
        print("step  target (mm from pick-up)   well off target   moved     ratio (siblings)   depth vs start   old well → new: downhill?")
        var g = r0.drives
        for (i0, x) in path.enumerated() {
            let i = i0 + 1
            g = rig.step(g, from: i0 == 0 ? w0 : path[i0 - 1], to: x)
            let (r, U) = rig.evaluate(g, target: x)
            let wNew = r.targetWell ?? x
            var rise = 0.0, last = ForceCompiler.interpolate(U, lattice: rig.lattice, at: prevWell)
            for q in 1...10 {
                let u = ForceCompiler.interpolate(U, lattice: rig.lattice, at: prevWell + (wNew - prevWell) * (Double(q) / 10))
                rise = max(rise, u - last)
                last = u
            }
            let barrier = rise / max(r.targetDepth, 1e-300)
            let moved = (wNew - prevWell).length
            let fine = r.targetOffset < 0.25e-3 && moved < 2 * stepLen && barrier <= 0.05
                && r.siblingRatio < 1 && r.targetDepth >= 0.5 * depth0
            if !fine { ok = false }
            if r.siblingRatio >= 0.5 { notUnique += 1 }
            worstRatio = max(worstRatio, r.siblingRatio); worstOff = max(worstOff, r.targetOffset)
            minDepth = min(minDepth, r.targetDepth / max(depth0, 1e-300))
            if i % 4 == 0 || i <= 2 || !fine {
                let d = x - w0
                print(String(format: "%3d   (%5.2f, %5.2f, %5.2f)        %5.2f mm         %4.2f mm   %5.2f (%3d)      %5.2f            %@",
                             i, d.x * 1000, d.y * 1000, d.z * 1000, r.targetOffset * 1000, moved * 1000,
                             r.siblingRatio, r.siblings, r.targetDepth / max(depth0, 1e-300),
                             barrier <= 0.05 ? "yes" : String(format: "barrier %.0f%% of depth", barrier * 100)))
            }
            prevWell = wNew
            steps = i
        }
        print(String(format: "worst offset %.2f mm · shallowest %.2f of the start · worst sibling ratio %.2f (%d of %d steps ≥ 0.5)",
                     worstOff * 1000, minDepth, worstRatio, notUnique, steps))
        let gate = GateResult(id: "G-P1", name: "bead carried 5 mm up and 5 mm across between the open-air plates: on the point, continuous, downhill, still the deepest well",
                              measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                              detail: String(format: "%@; %d steps of 0.25 mm, %@; worst offset %.2f mm, shallowest %.2f; sibling ratio worst %.2f, %d steps ≥ 0.5",
                                             rig.chamberText, steps, rig.tonesText, worstOff * 1000, minDepth, worstRatio, notUnique))
        print(gate.line)
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "carry-\(arr.tag)", gates: [gate], durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        return ok ? 0 : 1
    }

    /// A bead integrated through a carry: loaded gently at the first point
    /// (20× drag for 0.3 s), released to air drag, then each step's potential
    /// ramped linearly from the old drive to the new on top of the field's
    /// settling time. `Us`: the potential of each drive per unit power on
    /// `lattice`; `power` scales them to newtons.
    static func ride(Us: [[Double]], lattice fb: FieldLattice, path: [Vec3], power P: Double, stepTime Tstep: Double,
                     particle: ParticleMaterial, settling tauU: Double, record wanted: Bool = false,
                     mult: Double = 4) -> (escaped: Bool, worst: Double, end: Vec3, record: String?, start: Vec3) {
        let mass = particle.mass(), g0 = 9.81, gamma = 6 * Double.pi * 1.81e-5 * particle.radius
        let w0 = path[0]
        var x = w0, v = Vec3(0, 0, 0)
        var t = 0.0
        let dt = 1e-4
        var worst = 0.0, escaped = false
        var record: String? = wanted ? "" : nil
        func step(from a: Int, to b: Int, duration: Double, drag: Double, ramp: Bool) {
            var tt = 0.0
            while tt < duration && !escaped {
                let cmd = ramp ? min(1, tt / duration) : 1
                let lagged = max(0, cmd - tauU / duration * (1 - exp(-tt / max(tauU, 1e-12))))
                let wb = a == b ? 1 : lagged, wa = 1 - wb
                guard let ga = latticeGradient(fb, Us[a], x), let gb = latticeGradient(fb, Us[b], x) else { escaped = true; return }
                let force = (ga * wa + gb * wb) * (-P) + Vec3(0, 0, -mass * g0) - v * (gamma * drag)
                v = v + force * (dt / mass)
                x = x + v * dt
                tt += dt; t += dt
                if a != b { worst = max(worst, (x - path[b]).length) }
                if record != nil, Int((t / 1e-3).rounded()) != Int(((t - dt) / 1e-3).rounded()) {
                    record! += String(format: "%.0f,%.0f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", mult, Tstep * 1000, t,
                                      (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000,
                                      (path[b].x - w0.x) * 1000, (path[b].y - w0.y) * 1000, (path[b].z - w0.z) * 1000)
                }
            }
        }
        step(from: 0, to: 0, duration: 0.3, drag: 20, ramp: false)   // gentle loading
        step(from: 0, to: 0, duration: 0.2, drag: 1, ramp: false)
        let start = x                                            // where the bead sits before the carry
        for i in 1..<Us.count where !escaped { step(from: i - 1, to: i, duration: Tstep, drag: 1, ramp: true) }
        if !escaped { step(from: Us.count - 1, to: Us.count - 1, duration: 0.4, drag: 1, ramp: false) }
        return (escaped, worst, x, record, start)
    }

    // MARK: - fly

    /// A bead that moves (G-P2): a 200 µm PLA bead integrated through the
    /// carry sequence — time-averaged Gor'kov force, gravity, Stokes drag
    /// (streaming ignored). A drive switch reaches the bead over the field's
    /// settling time, modelled as an exponential cross-fade of the potential.
    static func fly(_ ctx: MetalContext, _ args: [String]) throws -> Int32 {
        let t0 = Date()
        guard let c = try carrySequence(ctx, args) else { return 1 }
        let rig = c.rig, path = c.path, drives = c.drives, particle = rig.particle
        let w0 = path[0]
        print(String(format: "carry compiled: %d drives (%.0f s)", drives.count, Date().timeIntervalSince(t0)))
        // A fine box around the path, 0.1 mm, where the bead can go.
        let (fb, fine) = try P0Command.box(path, rig), fs = fb.spacing
        let Us = drives.map { fine.potential($0, particle: particle) }
        func gradU(_ U: [Double], _ x: Vec3) -> Vec3? { latticeGradient(fb, U, x) }
        // Power: twice what holds the bead at the pick-up.
        let mass = particle.mass(), g0 = 9.81
        var fUp = 0.0
        for q in -15...15 { if let gr = gradU(Us[0], w0 + Vec3(0, 0, Double(q) * fs)) { fUp = max(fUp, -gr.z) } }
        guard fUp > 0 else { print("the pick-up well pushes nowhere upward"); return 1 }
        let power = 2 * mass * g0 / fUp
        var margins: [Double] = []
        for (i, U) in Us.enumerated() {
            var up = 0.0
            for q in -15...15 { if let gr = gradU(U, path[i] + Vec3(0, 0, Double(q) * fs)) { up = max(up, -gr.z) } }
            margins.append(up * power / (mass * g0))
        }
        let weakest = margins.indices.min { margins[$0] < margins[$1] }!
        print(String(format: "lift margin along the path: min %.2f at step %d, median %.2f",
                     margins[weakest], weakest, margins.sorted()[margins.count / 2]))
        let gamma = 6 * Double.pi * 1.81e-5 * particle.radius
        let tauU = rig.settling
        print(String(format: "%@, %@; carry 5 mm up + 5 mm across in 0.25 mm steps; %@; at 2 × holding the hardest-driven element is at %.2f of its ceiling",
                     rig.chamberText, rig.tonesText, bead(rig.array).name, drives.map { rig.elementGate($0, power: power, label: "").measured }.max() ?? .infinity))
        print(String(format: "bead: m %.2e kg, drag %.2e kg/s (1/e in %.0f ms); potential settles with τ = %.1f ms",
                     mass, gamma, mass / gamma * 1000, tauU * 1000))
        print("each step ramps the potential linearly from the old drive to the new (cross terms ignored), on top of the settling τ;")
        print("the bead is loaded gently (20× drag for 0.3 s), then released to air drag")
        print("drive × holding   step time   carry time   worst lag   at the end   result")
        var gates: [GateResult] = []
        var csv = "power_x,step_ms,t_s,x_mm,y_mm,z_mm,well_x_mm,well_y_mm,well_z_mm\n"
        var anyCarried = false
        // What each drive level asks of the hardest-driven element anywhere on the path.
        let ask1 = drives.map { rig.elementGate($0, power: power / 2, label: "").measured }.max() ?? .infinity
        for mult in [1.25, 1.5, 2.0, 4.0, 8.0] {
            let P = power * mult / 2
            let ask = ask1 * mult.squareRoot()
            for Tstep in [0.01, 0.02, 0.04, 0.08] {
                let ride = PlaceCommand.ride(Us: Us, lattice: fb, path: path, power: P, stepTime: Tstep, particle: particle,
                                             settling: tauU, record: mult == 4 && Tstep == 0.04, mult: mult)
                let escaped = ride.escaped, worst = ride.worst, x = ride.end
                let record = ride.record
                let end = (x - path.last!).length
                let carried = !escaped && end < 0.5e-3
                if carried && ask < 1 { anyCarried = true }
                print(String(format: "    %5.2f×          %4.0f ms     %5.2f s      %5.2f mm     %5.2f mm     %@%@",
                             mult, Tstep * 1000, Tstep * Double(drives.count - 1), worst * 1000,
                             escaped ? .nan : end * 1000,
                             escaped ? "escaped the trap" : (carried ? "carried" : "left behind"),
                             ask < 1 ? "" : String(format: " — but asks %.2f× what an element can give", ask)))
                gates.append(GateResult(id: "FLY", name: String(format: "%.2f× holding drive, %.0f ms per 0.25 mm step", mult, Tstep * 1000),
                                        measured: escaped ? .infinity : end, threshold: 0.5e-3, comparison: .informational,
                                        detail: String(format: "worst lag %.2f mm, %@; the hardest-driven element at %.2f of its ceiling", worst * 1000,
                                                       escaped ? "escaped" : (carried ? "carried" : "left behind"), ask)))
                if let r = record { csv += r }
            }
        }
        let g2 = GateResult(id: "G-P2", name: "a \(bead(rig.array).name) bead, integrated through the open-air plates' fields, rides the carry 5 mm up and 5 mm across",
                            measured: anyCarried ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                            detail: "\(rig.chamberText); at least one drive level the elements can give (G-E1 < 1) and step time carries it to within 0.5 mm of the drop-off")
        print(g2.line)
        gates.append(g2)
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "fly-\(rig.array.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
            try? csv.write(toFile: "Receipts/fly_\(rig.array.tag)_trajectory_4x_40ms.csv", atomically: true, encoding: .utf8)
        }
        return anyCarried ? 0 : 1
    }
}
