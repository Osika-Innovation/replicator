import FieldCore
import FieldGPU
import Foundation

// The first builds between the open-air plates (G-B1: N beads in a row on a
// support; G-B2: a tetrahedron), ported from the glass-chamber `build` of
// Round 9. The procedure is the same — gentle load, carry, hover, closed-loop
// lowering, slide in, fuse on touch, the part scattering into the field — and
// so are the bead's mechanics. What changed is the field:
//
//  * the plates' matrix-free operator (`ArrayFieldGPU`) instead of stored
//    cavity rows, with the placed beads added by `PartFieldGPU`;
//  * since nothing is stored, a field is evaluated only where it is read: a
//    small box round the aim for the balance and the stiffness, a ±2 mm box
//    round the aim for the bead's flight, the 25 µm grid round the part;
//  * a carry step re-aims the array (`PlaceRig.step`).
//
// Not modelled, as before: the support's own scattering (an acoustically
// open mesh), streaming.

enum BuildCommand {
    static func run(_ args: [String]) -> Int32 {
        do {
            let ctx = try MetalContext()
            if args.contains("--check-part") { return try checkPart(ctx, args) }
            return try build(ctx, args)
        } catch { print("GPU unavailable: \(error)"); return 2 }
    }

    /// G-A4: the part field's adjoint against central differences of Σ w U.
    /// U is quadratic in the drive, so a central difference is exact up to
    /// rounding whatever the step.
    static func checkPart(_ ctx: MetalContext, _ args: [String]) throws -> Int32 {
        let rig = try PlaceRig(ctx: ctx, array: plateArray(args), freqs: [40_000, 62_000], half: 3e-3)
        let c = rig.centre
        let a = rig.particle.radius
        let part = Scatterers(centers: [c + Vec3(0, 0, -2e-3 + a), c + Vec3(2 * a + 10e-6, 0, -2e-3 + a)],
                              particle: rig.particle, medium: rig.air, fused: true)
        let L = FieldLattice(origin: c + Vec3(-0.2e-3, -0.2e-3, -2e-3), spacing: 0.1e-3, nx: 8, ny: 6, nz: 6)
        let field = PartFieldGPU(base: try rig.field(on: L), part: part)
        var rng = SplitMix64(seed: 5)
        let w = (0..<L.count).map { _ in rng.nextUnit() - 0.3 }
        let g = rig.nodeStart(at: c + Vec3(0.1e-3, 0, -1.8e-3))
        func J(_ d: [[Complex]]) -> Double { zip(field.potential(d, particle: rig.particle), w).reduce(0) { $0 + $1.0 * $1.1 } }
        let adj = field.adjoint(g, weights: w, particle: rig.particle)
        let bare = PartFieldGPU(base: field.base, part: Scatterers(centers: [], particle: rig.particle, medium: rig.air))
        let adjBare = bare.adjoint(g, weights: w, particle: rig.particle)
        var num = 0.0, den = 0.0, partShare = 0.0
        for (t, e) in [(0, 3), (0, 200), (1, 77), (1, 300), (0, 191), (1, 383)] {
            let step = 0.5 * g[t][e].magnitude
            for (im, unit) in [(false, Complex(step, 0)), (true, Complex(0, step))] {
                var gp = g, gm = g
                gp[t][e] += unit; gm[t][e] += unit * -1.0
                let fd = (J(gp) - J(gm)) / (2 * step)
                let an = 2 * (im ? adj[t][e].im : adj[t][e].re)
                num += (fd - an) * (fd - an); den += fd * fd
                partShare += pow(an - 2 * (im ? adjBare[t][e].im : adjBare[t][e].re), 2)
            }
        }
        let gate = GateResult(id: "G-A4", name: "part field (plates + two scattering beads): adjoint vs central differences of Σ w U",
                              measured: (num / den).squareRoot(), threshold: 1e-2, comparison: .lessThan,
                              detail: String(format: "12 drive entries, 2 tones; the beads change the gradient by %.1f%% (rms)",
                                             100 * (partShare / den).squareRoot()))
        print(gate.line)
        return gate.passed ? 0 : 1
    }

    static func build(_ ctx: MetalContext, _ args: [String]) throws -> Int32 {
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let debug = args.contains("--debug"), trace = args.contains("--trace")
        var N = max(1, arg("--beads").flatMap(Int.init) ?? 5)
        // --shape row (default): N beads in a line; tetra: three touching on the
        // support and a fourth in their pocket.
        let shape = arg("--shape") ?? "row"
        if shape == "tetra" { N = 4 }
        let scatterOn = !args.contains("--no-scatter")
        let arr = plateArray(args)
        let rig = try PlaceRig(ctx: ctx, array: arr, freqs: PlaceCommand.spread10)
        let air = rig.air, particle = rig.particle, freqs = rig.freqs
        let r0 = rig.pickUp()
        guard let w0 = r0.targetWell else { print("no trap at the pick-up"); return 1 }
        let a = particle.radius
        let zs = w0.z - 2e-3                          // the support: bead bottoms rest here
        let gapAim = 10e-6                            // aim 10 µm off contact: a miss leaves a gap, not a perch
        let first = Vec3(w0.x + 0.5e-3, w0.y, zs + a)
        let fs = 0.1e-3, ns = 25e-6                   // the fine spacing; the spacing near the part

        struct Placed { var p: Vec3; var on: Int; var site: Vec3 }  // on: −1 = support, j = fused to bead j
        var placed: [Placed] = []
        var part = Scatterers(centers: [], particle: particle, medium: air, fused: true)
        var nearLat: FieldLattice? = nil               // 25 µm around the part
        var nearField: PartFieldGPU? = nil
        func withPartField(_ L: FieldLattice, part on: Bool) throws -> PartFieldGPU {
            PartFieldGPU(base: try rig.field(on: L),
                         part: on && scatterOn ? part : Scatterers(centers: [], particle: particle, medium: air, fused: true))
        }
        /// A cube of (2·cells + 1)³ nodes centred on x.
        func cube(_ x: Vec3, spacing sp: Double, cells: Int) -> FieldLattice {
            let h = Double(cells) * sp
            return FieldLattice(origin: x - Vec3(h, h, h), spacing: sp, nx: 2 * cells + 1, ny: 2 * cells + 1, nz: 2 * cells + 1)
        }
        func inside(_ L: FieldLattice, _ x: Vec3, margin: Int) -> Bool {
            let f = (x - L.origin) / L.spacing
            return f.x >= Double(margin) && f.y >= Double(margin) && f.z >= Double(margin)
                && f.x <= Double(L.nx - 1 - margin) && f.y <= Double(L.ny - 1 - margin) && f.z <= Double(L.nz - 1 - margin)
        }
        func updatePart() throws {
            part.centers = placed.map(\.p)
            if scatterOn && !placed.isEmpty {
                // The near grid: the part and the next site, from the support up past the hover height.
                let xs = part.centers.map(\.x), ys = part.centers.map(\.y)
                let nlo = Vec3(xs.min()! - 0.45e-3, ys.min()! - 0.45e-3, zs - 0.05e-3)
                let nhi = Vec3(xs.max()! + 0.45e-3, ys.max()! + 0.45e-3, zs + 0.6e-3)
                let L = FieldLattice(origin: nlo, spacing: ns, nx: Int(((nhi.x - nlo.x) / ns).rounded()) + 1,
                                     ny: Int(((nhi.y - nlo.y) / ns).rounded()) + 1, nz: Int(((nhi.z - nlo.z) / ns).rounded()) + 1)
                nearLat = L
                nearField = try withPartField(L, part: true)
            } else { nearLat = nil; nearField = nil }
        }
        // Placed beads' own push: the local field (plates + the other beads) at a
        // ±10 µm stencil round each bead.
        let hst = 10e-6
        let stencil = [Vec3(0, 0, 0), Vec3(hst, 0, 0), Vec3(-hst, 0, 0), Vec3(0, hst, 0), Vec3(0, -hst, 0),
                       Vec3(0, 0, hst), Vec3(0, 0, -hst)]
        func pushes(_ g: [[Complex]]) -> [Vec3] {
            guard !placed.isEmpty else { return [] }
            let pf = PartFieldGPU(base: rig.field, part: scatterOn ? part : Scatterers(centers: [], particle: particle, medium: air))
            return placed.indices.map { j in
                let U = (try? pf.potential(g, particle: particle, at: stencil.map { placed[j].p + $0 }, skip: j))
                    ?? [Double](repeating: 0, count: 7)
                return Vec3(U[1] - U[2], U[3] - U[4], U[5] - U[6]) * (1 / (2 * hst))
            }
        }
        let mass = particle.mass(), g0 = 9.81, weight = mass * g0
        let boxCells = 20                              // the flight box: ±2 mm round the aim at 0.1 mm
        func flightBox(_ g: [[Complex]], _ aim: Vec3) throws -> (FieldLattice, [Double]) {
            let L = cube(aim, spacing: fs, cells: boxCells)
            return (L, try withPartField(L, part: true).potential(g, particle: particle))
        }
        let (pickL, Upick) = try flightBox(r0.drives, w0)
        var fUp = 0.0
        for q in -15...15 { if let gr = latticeGradient(pickL, Upick, w0 + Vec3(0, 0, Double(q) * fs)) { fUp = max(fUp, -gr.z) } }
        guard fUp > 0 else { print("the pick-up well pushes nowhere upward"); return 1 }
        let power = 4 * weight / fUp                  // 4× the holding drive (fly: carries at every step time)
        let gamma = 6 * Double.pi * 1.81e-5 * a
        let tauU = rig.settling
        let Tstep = 0.04, dt = 1e-4
        // Compile the FORCE BALANCE, not the potential minimum: at power P the
        // trap must hold the weight at the aim, P∇U(x) = −mg ẑ, so the bead
        // rests on its aim instead of hanging below and aside.
        let hold = Vec3(0, 0, -weight / power)
        /// The grid that resolves the field at x: 25 µm inside the near grid, 0.1 mm elsewhere.
        func spacingAt(_ x: Vec3, margin: Int) -> Double {
            if let L = nearLat, inside(L, x, margin: margin) { return ns }
            return fs
        }
        // `withPart: false` aims the trap on the plates' field alone — for the final
        // approach: compiled WITH the part, the balance leans the trap away to
        // hold the bead off its neighbour's pull, and the bead, on a ridge
        // between the two, falls outward; aimed without it, trap and attraction
        // pull the same way, into contact.
        func placeFine(_ g: [[Complex]], _ x: Vec3, withPart: Bool = true, carry: Double = 1) throws -> [[Complex]] {
            let sp = withPart ? spacingAt(x, margin: 3) : fs
            let f = try withPartField(cube(x, spacing: sp, cells: 4), part: withPart)
            let mv = ForceCompiler.moveWell(field: f, particle: particle, drives: g, to: x, iterations: 6,
                                            balance: withPart ? hold : hold * carry)
            if debug && sp == ns {
                print(String(format: "      near-part balance at (%.3f, %.3f, %.3f) mm: residual %.1f µm",
                             (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, mv.residual * 1e6))
            }
            return mv.drives
        }
        // The weakest of a trap's three stiffnesses at x (N/m), from second differences
        // of P·U on the grid that resolves x — a balance can sit on a saddle.
        func weakest(_ g: [[Complex]], _ x: Vec3, withPart: Bool = true) throws -> Double {
            let sp = withPart ? spacingAt(x, margin: 4) : fs
            let L = cube(x, spacing: sp, cells: 4)
            let U = try withPartField(L, part: withPart).potential(g, particle: particle)
            let hh = 2 * sp
            func u(_ y: Vec3) -> Double { ForceCompiler.interpolate(U, lattice: L, at: y) }
            let c = u(x)
            return [Vec3(hh, 0, 0), Vec3(0, hh, 0), Vec3(0, 0, hh)]
                .map { (u(x + $0) - 2 * c + u(x - $0)) / (hh * hh) * power }.min()!
        }
        let pickDrive = try placeFine(rig.step(r0.drives, from: w0, to: w0, balance: hold), w0)

        var push = [Double]()                          // max acoustic force on each placed bead afterwards, × weight
        var csv = "bead,t_s,x_mm,y_mm,z_mm\n"
        var t = 0.0
        var misses = 0
        print(String(format: "%@, 10 tones, 4× holding drive (%.2f m/s rms per element); %d PLA beads Ø%.0f µm (%@), support %.1f mm below the pick-up",
                     rig.chamberText, (power / Double(arr.channels * freqs.count)).squareRoot(), N, 2 * a * 1e6, shape, (w0.z - zs) * 1000))
        print(scatterOn ? "the part scatters: placed beads join the field (coupled monopoles + dipoles), 25 µm grid near the part"
                        : "the part is acoustically invisible (--no-scatter)")
        print("each bead: gentle load → carry (0.25 mm, 80 ms steps) → hover 0.15 mm up → closed-loop lowering (0.05 mm steps) → fuse on first touch")
        // The row's direction. Neighbours in an oscillating flow attract side by
        // side and repel end to end (G-S2), so a row laid along the local flow
        // does not stay there. After the first bead lands, the twin reads the
        // flow at it (Σ over tones of Re ∇p ∇pᴴ/ω², horizontal part) and lays the
        // row across it (`--row-dir x|y` forces one).
        var rowDir = Vec3(1, 0, 0)
        var flowNote = "row along x (fixed)"
        func chooseRowDirection(drive g: [[Complex]]) throws {
            if let d = arg("--row-dir") {
                rowDir = d == "y" ? Vec3(0, 1, 0) : Vec3(1, 0, 0)
                flowNote = "row along \(d) (forced)"
                return
            }
            guard scatterOn, let p0 = placed.first?.p else { return }
            var txx = 0.0, txy = 0.0, tyy = 0.0, tzz = 0.0
            for f in freqs.indices {
                let S = try rig.field.fields(g[f], tone: f, at: [p0])
                let w2 = pow(2 * Double.pi * freqs[f], 2)
                txx += S[1].magnitudeSquared / w2; tyy += S[2].magnitudeSquared / w2; tzz += S[3].magnitudeSquared / w2
                txy += (S[1] * S[2].conjugate).re / w2
            }
            // Horizontal block's eigenvector with the SMALLER eigenvalue: least flow along it.
            let tr = txx + tyy, det = txx * tyy - txy * txy
            let lMin = tr / 2 - max(0, tr * tr / 4 - det).squareRoot()
            var d = abs(txy) > 1e-30 ? Vec3(txy, lMin - txx, 0) : (txx <= tyy ? Vec3(1, 0, 0) : Vec3(0, 1, 0))
            d = d * (1 / d.length)
            if d.x < 0 || (abs(d.x) < 1e-9 && d.y < 0) { d = d * -1 }
            rowDir = d
            let total = txx + tyy + tzz
            flowNote = String(format: "flow at the first bead: %.0f%% along x, %.0f%% along y, %.0f%% along z → row laid along (%.2f, %.2f)",
                              100 * txx / total, 100 * tyy / total, 100 * tzz / total, d.x, d.y)
        }
        // Sites are laid off where the earlier beads actually came to rest.
        func siteFor(_ k: Int) -> Vec3 {
            let d = 2 * a + gapAim
            if shape == "tetra" && k == 2 {
                let p0 = placed[0].p, p1 = placed[1].p
                let mid = (p0 + p1) * 0.5, half = (p1 - p0).length / 2
                let side = Vec3(-(p1.y - p0.y), p1.x - p0.x, 0) * (1 / (2 * half))
                let off = max(0, d * d - half * half).squareRoot()
                return Vec3(mid.x + side.x * off, mid.y + side.y * off, zs + a)
            }
            if shape == "tetra" && k == 3 {
                let c = (placed[0].p + placed[1].p + placed[2].p) * (1.0 / 3)
                let rc = placed.prefix(3).reduce(0.0) { $0 + Vec3($1.p.x - c.x, $1.p.y - c.y, 0).length } / 3
                return Vec3(c.x, c.y, zs + a + max(0, d * d - rc * rc).squareRoot())
            }
            return k == 0 ? first : Vec3(placed[k - 1].p.x + rowDir.x * d, placed[k - 1].p.y + rowDir.y * d, zs + a)
        }
        // With the part in the field, a bead is not lowered straight onto a site
        // beside a neighbour: close in, the neighbour's scattering turns the trap
        // into a saddle. It lands `backOff` behind its site, outside that reach,
        // and is slid in along the support, where the side-by-side attraction
        // takes it the last micrometres.
        let backOff = arg("--backoff").flatMap(Double.init).map { $0 * 1e-3 } ?? (scatterOn ? 0.6e-3 : 0)
        let muStatic = 0.02, muKinetic = 0.01           // a bead ROLLS on the support: rolling resistance ~1 % of the load
        for k in 0..<N {
            let site = siteFor(k)
            let stack = site.z > zs + a + 1e-6          // rests on beads, not the support
            var approach = site
            var slideDir = Vec3(0, 0, 0)
            if let nb = placed.min(by: { ($0.p - site).length < ($1.p - site).length }), !stack, backOff > 0 {
                // Slide in from where every bead it must touch pulls equally: away from
                // the one neighbour, or down the bisector of a notch between two.
                let touching = placed.filter { ($0.p - site).length < 2 * a + 3 * gapAim }
                let centre = touching.count >= 2
                    ? touching.reduce(Vec3(0, 0, 0)) { $0 + $1.p } * (1 / Double(touching.count)) : nb.p
                var u = Vec3(site.x - centre.x, site.y - centre.y, 0)
                u = u * (1 / max(u.length, 1e-12))
                approach = site + u * backOff
                slideDir = u * -1
            }
            // A bead laid ON beads is dropped, not pushed: it hovers above the pocket,
            // is centred, and falls the rest with the drive off. How far above: the
            // lowest height at which the trap, with the part in the field, keeps at
            // least half the sideways stiffness it has without it. Between the plates
            // the trap is soft sideways (~12 Hz at this drive), and the base beads'
            // scattering makes it a saddle further up than in the glass chamber: at
            // 0.5 mm the bead drifted 0.24 mm and fell beside the pocket.
            var hoverUp = stack ? 0.5e-3 : 0.15e-3
            if stack && scatterOn {
                for up in stride(from: 0.5e-3, through: 1.5e-3, by: 0.25e-3) {
                    let pt = approach + Vec3(0, 0, up)
                    let g = try placeFine(rig.step(pickDrive, from: w0, to: pt, balance: hold), pt)
                    let with = try weakest(g, pt), bare = try weakest(g, pt, withPart: false)
                    hoverUp = up
                    if debug {
                        print(String(format: "      hover %.2f mm above the pocket: weakest stiffness %.2e N/m with the part, %.2e without",
                                     up * 1000, with, bare))
                    }
                    if bare > 0 && with >= 0.5 * bare { break }
                }
            }
            let hover = approach + Vec3(0, 0, hoverUp)
            // Drives along the way: [0] at the pick-up (force-balanced), then one per
            // waypoint. Each carries its potential on the flight box round its aim, on
            // the near grid, and its push on every placed bead.
            var drives: [[[Complex]]] = [pickDrive]
            var boxes: [(FieldLattice, [Double])] = [try flightBox(pickDrive, w0)]
            var UsNear: [[Double]] = nearField.map { [$0.potential(pickDrive, particle: particle)] } ?? []
            var pushBy: [[Vec3]] = [pushes(pickDrive)]
            var aims: [Vec3] = [w0]
            func addDrive(to x: Vec3, withPart: Bool = true, carry: Double = 1, checkStable: Bool = true) throws {
                // Rivals over the whole probe volume on the plates' field (the part is a
                // negligible perturbation there); the balance then on the grid that
                // resolves the part.
                var g = try placeFine(rig.step(drives.last!, from: aims.last!, to: x, balance: hold), x,
                                      withPart: withPart, carry: carry)
                // A trap whose balance sits on a saddle throws the bead: stiffen in
                // place, then re-compile, longer and from the pick-up drive, and keep
                // the stiffest.
                if checkStable {
                    var best = try weakest(g, x)
                    if best <= 0 {
                        let sp = withPart ? spacingAt(x, margin: 4) : fs
                        let f = try withPartField(cube(x, spacing: sp, cells: 4), part: withPart)
                        let gs = ForceCompiler.stiffen(field: f, particle: particle, drives: g, at: x,
                                                       balance: hold * carry, step: 2 * sp)
                        let ss = try weakest(gs, x)
                        if ss > best { best = ss; g = gs }
                        for (start, from) in [(drives.last!, aims.last!), (pickDrive, w0)] where best <= 0 {
                            let g2 = try placeFine(ForceCompiler.carryStep(field: rig.field, particle: particle, wavelength: rig.lam40,
                                                                           options: rig.options, drives: rig.steer(start, from: from, to: x),
                                                                           to: x, iterations: 150, balance: hold), x,
                                                   withPart: withPart, carry: carry)
                            let s2 = try weakest(g2, x)
                            if s2 > best { best = s2; g = g2 }
                        }
                        if debug {
                            print(String(format: "      unstable trap at (%.3f, %.3f, %.3f) mm re-compiled: weakest stiffness now %.2e N/m",
                                         (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, best))
                        }
                    }
                }
                drives.append(g); boxes.append(try flightBox(g, x)); aims.append(x)
                if let nf = nearField { UsNear.append(nf.potential(g, particle: particle)) }
                pushBy.append(pushes(g))
            }
            func waypoints(_ from: Vec3, _ to: Vec3, _ step: Double) -> [Vec3] {
                let d = to - from, m = max(1, Int((d.length / step).rounded(.up)))
                return (1...m).map { from + d * (Double($0) / Double(m)) }
            }
            // The bead and its integrator.
            var x = w0, v = Vec3(0, 0, 0)
            var fused: Placed? = nil
            var resting = false
            var recent: [Vec3] = []
            func run(from ia: Int, to ib: Int, duration: Double, drag: Double, ramp: Bool, released: Bool = false) {
                var tt = 0.0
                recent.removeAll()
                while tt < duration && fused == nil {
                    let cmd = ramp ? min(1, tt / duration) : 1
                    let wb = ia == ib ? 1 : max(0, cmd - tauU / duration * (1 - exp(-tt / tauU))), wa = 1 - wb
                    // Near the part, the 25 µm grid resolves its scattered near field.
                    var ga: Vec3? = nil, gb: Vec3? = nil
                    if let L = nearLat, let na = latticeGradient(L, UsNear[ia], x, margin: 2),
                       let nb = latticeGradient(L, UsNear[ib], x, margin: 2) {
                        ga = na; gb = nb
                    } else {
                        ga = latticeGradient(boxes[ia].0, boxes[ia].1, x); gb = latticeGradient(boxes[ib].0, boxes[ib].1, x)
                    }
                    guard let ga, let gb else { return }
                    var force = (released ? Vec3(0, 0, 0) : (ga * wa + gb * wb) * (-power)) + Vec3(0, 0, -weight) - v * (gamma * drag)
                    // The support pushes back and holds by friction; it does not glue.
                    if x.z - a <= zs + 1e-7 && force.z < 0 {
                        let normal = -force.z
                        force = Vec3(force.x, force.y, 0)
                        if v.z < 0 { v = Vec3(v.x, v.y, 0) }
                        let vl = Vec3(v.x, v.y, 0), fl = Vec3(force.x, force.y, 0)
                        if vl.length < 1e-5 && fl.length <= muStatic * normal {
                            v = Vec3(0, 0, v.z); force = Vec3(0, 0, 0)
                        } else if vl.length >= 1e-5 {
                            force = force - vl * (muKinetic * normal / vl.length)
                        }
                    }
                    let vBefore = Vec3(v.x, v.y, 0)
                    v = v + force * (dt / mass)
                    // Kinetic friction stops a slide; it does not reverse it.
                    if x.z - a <= zs + 1e-7, v.x * vBefore.x + v.y * vBefore.y < 0 { v = Vec3(0, 0, v.z) }
                    x = x + v * dt
                    if x.z - a < zs { x = Vec3(x.x, x.y, zs + a); if v.z < 0 { v = Vec3(v.x, v.y, 0) } }
                    resting = x.z - a <= zs + 1e-6
                    tt += dt; t += dt
                    // The placed beads feel the field too — the plates' and the other beads'.
                    for q in placed.indices where q < pushBy[ia].count && q < pushBy[ib].count {
                        push[q] = max(push[q], ((pushBy[ia][q] * wa + pushBy[ib][q] * wb) * power).length / weight)
                    }
                    // A placed bead: the binder coat grips on touch and the machine releases
                    // the bead (drive off). For 0.15 s it stays in contact but settles under
                    // gravity along the beads it touches (joining any it meets) onto the
                    // support or into a pocket, heavily damped; then the bond cures.
                    if let j = placed.indices.first(where: { (x - placed[$0].p).length <= 2 * a }) {
                        var bonds = [j]
                        var xs = x, vs = v
                        func project() {
                            for _ in 0..<6 {
                                for q in bonds { let d = xs - placed[q].p; xs = placed[q].p + d * (2 * a / max(d.length, 1e-12)) }
                                if xs.z - a < zs { xs = Vec3(xs.x, xs.y, zs + a) }
                            }
                        }
                        project()
                        for _ in 0..<Int(0.15 / dt) {
                            let fsettle = Vec3(0, 0, -weight) - vs * (gamma * 50)
                            let prev = xs
                            vs = vs + fsettle * (dt / mass)
                            xs = xs + vs * dt
                            if let q = placed.indices.first(where: { !bonds.contains($0) && (xs - placed[$0].p).length < 2 * a }) {
                                bonds.append(q)
                            }
                            project()
                            vs = (xs - prev) * (1 / dt)
                            t += dt
                        }
                        x = xs; v = Vec3(0, 0, 0)
                        fused = Placed(p: xs, on: j, site: site)
                    }
                    if duration - tt < 0.02 { recent.append(x) }
                    if Int((t / 2e-3).rounded()) != Int(((t - dt) / 2e-3).rounded()) {
                        csv += String(format: "%d,%.4f,%.4f,%.4f,%.4f\n", k, t, (x.x - w0.x) * 1000,
                                      (x.y - w0.y) * 1000, (x.z - w0.z) * 1000)
                    }
                }
            }
            func mean(_ v: [Vec3]) -> Vec3 { v.isEmpty ? x : v.reduce(Vec3(0, 0, 0), +) * (1 / Double(v.count)) }
            // 1. Load gently at the pick-up.
            run(from: 0, to: 0, duration: 0.3, drag: 20, ramp: false)
            run(from: 0, to: 0, duration: 0.2, drag: 1, ramp: false)
            if debug {
                print(String(format: "  bead %d loaded: (%+.3f, %+.3f, %+.3f) mm from the well, %.1f mm/s", k,
                             (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, v.length * 1000))
            }
            // 2. Carry across at pick-up height, then down to the hover point: 80 ms
            //    per 0.25 mm step and a 50 ms settle.
            for wp in waypoints(w0, Vec3(hover.x, hover.y, w0.z), 0.25e-3) + waypoints(Vec3(hover.x, hover.y, w0.z), hover, 0.25e-3) {
                try addDrive(to: wp)
                run(from: drives.count - 2, to: drives.count - 1, duration: 2 * Tstep, drag: 1, ramp: true)
                run(from: drives.count - 1, to: drives.count - 1, duration: 0.05, drag: 1, ramp: false)
                if trace {
                    print(String(format: "    carry: aim (%+.3f, %+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the pick-up",
                                 (wp.x - w0.x) * 1000, (wp.y - w0.y) * 1000, (wp.z - w0.z) * 1000,
                                 (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000))
                }
            }
            run(from: drives.count - 1, to: drives.count - 1, duration: 0.3, drag: 1, ramp: false)
            if debug {
                print(String(format: "  bead %d at hover: (%+.3f, %+.3f, %+.3f) mm from the hover aim, %.1f mm/s", k,
                             (x.x - hover.x) * 1000, (x.y - hover.y) * 1000, (x.z - hover.z) * 1000, v.length * 1000))
            }
            // 3. Closed-loop lowering onto the support; a bead laid on beads is centred at the
            //    hover and dropped.
            var aim = aims.last!
            var zAim = hover.z
            var steps = 0
            if stack {
                for _ in 0..<3 {
                    let seen = mean(recent)
                    aim = Vec3(aim.x + 0.5 * (approach.x - seen.x), aim.y + 0.5 * (approach.y - seen.y), hover.z)
                    try addDrive(to: aim)
                    run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                    run(from: drives.count - 1, to: drives.count - 1, duration: 0.2, drag: 1, ramp: false)
                }
                if trace {
                    print(String(format: "    drop from (%+.3f, %+.3f, %+.3f) mm off the pocket", (x.x - site.x) * 1000,
                                 (x.y - site.y) * 1000, (x.z - site.z) * 1000))
                }
                run(from: drives.count - 1, to: drives.count - 1, duration: 0.5, drag: 1, ramp: false, released: true)
                steps = 99
            }
            while fused == nil && !resting && zAim > approach.z - 0.5e-3 && steps < 20 {
                let seen = mean(recent)
                // Half the miss per step: a bead still swinging is not chased.
                aim = Vec3(aim.x + 0.5 * (approach.x - seen.x), aim.y + 0.5 * (approach.y - seen.y), zAim - 0.05e-3)
                zAim -= 0.05e-3
                try addDrive(to: aim, withPart: !stack)
                run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                if fused == nil { run(from: drives.count - 1, to: drives.count - 1, duration: 0.15, drag: 1, ramp: false) }
                steps += 1
                if trace {
                    print(String(format: "    lower %d: aim (%+.3f, %+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the site%@", steps,
                                 (aim.x - site.x) * 1000, (aim.y - site.y) * 1000, (aim.z - site.z) * 1000,
                                 (x.x - site.x) * 1000, (x.y - site.y) * 1000, (x.z - site.z) * 1000,
                                 fused != nil ? " — gripped" : (resting ? " — on the support" : "")))
                }
            }
            // 4. Slide in along the support: to the site and 30 µm past it, 20 µm a step.
            if fused == nil && resting && slideDir.length > 0 {
                var sOff = 0.0
                while fused == nil && sOff < backOff + 30e-6 {
                    sOff += 20e-6
                    let tgt = approach + slideDir * sOff
                    // The trap carries 90 % of the weight: the bead rolls, pressed lightly on the support.
                    try addDrive(to: Vec3(tgt.x, tgt.y, site.z), withPart: false, carry: 0.9, checkStable: false)
                    run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                    if fused == nil { run(from: drives.count - 1, to: drives.count - 1, duration: 0.1, drag: 1, ramp: false) }
                    if trace {
                        print(String(format: "    slide %.0f µm: aim (%+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the site%@", sOff * 1e6,
                                     (tgt.x - site.x) * 1000, (tgt.y - site.y) * 1000,
                                     (x.x - site.x) * 1000, (x.y - site.y) * 1000, (x.z - site.z) * 1000,
                                     fused != nil ? " — gripped" : ""))
                    }
                }
            }
            // 5. Cure: a bead resting on the support that touched no bead is fixed where it lies.
            if fused == nil && resting { fused = Placed(p: Vec3(x.x, x.y, zs + a), on: -1, site: site) }
            if let f = fused {
                placed.append(f); push.append(0)
                if k == 0 {
                    try chooseRowDirection(drive: drives.last!)
                    // A tetrahedron's apex bead comes down a column 0.6 mm out along the
                    // notch's bisector, which can be untrappable. Before committing, compile
                    // test traps at eight heights down both candidate columns on the plates'
                    // field and keep the orientation with more trappable heights (then the
                    // larger median stiffness).
                    if shape == "tetra" && arg("--row-dir") == nil {
                        func column(_ dir: Vec3) throws -> (stable: Int, median: Double) {
                            let d = 2 * a + gapAim
                            let p0 = placed[0].p, p1 = p0 + dir * d
                            let perp = Vec3(-dir.y, dir.x, 0)
                            let apex = (p0 + p1) * 0.5 + perp * (d * 3.0.squareRoot() / 2)
                            let top = apex + perp * backOff
                            var ks: [Double] = []
                            var g = pickDrive
                            var from = w0
                            for q in 0..<8 {
                                let pt = Vec3(top.x, top.y, zs + a + 1.55e-3 - Double(q) * 0.2e-3)
                                g = try placeFine(rig.step(g, from: from, to: pt, balance: hold), pt, withPart: false)
                                from = pt
                                ks.append(try weakest(g, pt, withPart: false))
                            }
                            return (ks.filter { $0 > 0 }.count, ks.sorted()[ks.count / 2])
                        }
                        let alt = Vec3(-rowDir.y, rowDir.x, 0)
                        let cA = try column(rowDir), cB = try column(alt)
                        if cB.stable > cA.stable || (cB.stable == cA.stable && cB.median > cA.median) { rowDir = alt }
                        flowNote += String(format: "; apex columns trappable at %d/8 vs %d/8 heights → base along (%.2f, %.2f)",
                                           cA.stable, cB.stable, rowDir.x, rowDir.y)
                    }
                    print("  " + flowNote)
                }
                try updatePart()                          // the part grows into the field
                print(String(format: "  bead %d placed (%.0f s)", k, Date().timeIntervalSince(t0)))
            } else {
                misses += 1
                print(String(format: "  bead %d: not placed (at %.2f, %.2f, %.2f mm from the pick-up)", k,
                             (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000))
                break
            }
        }
        print("bead   site (µm from the first site)   placed at             miss      fixed by          gaps to the beads it rests against   pushed afterwards")
        var gaps: [Double] = []
        var touching: [Int] = []
        for (k, b) in placed.enumerated() {
            let rel = (b.p - first) * 1e6, srel = (b.site - first) * 1e6
            let miss = (b.p - b.site).length * 1e6
            // Its neighbours: earlier beads it rests against (gap under 0.1 mm).
            let near = placed.prefix(k).map { ($0.p - b.p).length - 2 * a }.filter { $0 < 0.1e-3 }
            gaps += near
            touching.append(near.filter { abs($0) < 30e-6 }.count)
            let gapText = near.isEmpty ? "—" : near.map { String(format: "%.1f", $0 * 1e6) }.joined(separator: ", ") + " µm"
            print(String(format: "%3d    (%6.1f, %6.1f, %5.1f)        (%6.1f, %6.1f, %5.1f)  %5.1f µm  %@  %@  %@",
                         k, srel.x, srel.y, srel.z, rel.x, rel.y, rel.z, miss,
                         (b.on < 0 ? "cured on support" : String(format: "gripped bead %d ", b.on)) as NSString,
                         gapText.padding(toLength: 36, withPad: " ", startingAt: 0) as NSString,
                         k == placed.count - 1 ? "—" : String(format: "%.2f × weight", push[k])))
        }
        let worstGap = gaps.map(abs).max() ?? 0
        let worstPush = push.dropLast().max() ?? 0
        let ok: Bool
        let gate: GateResult
        let how = rig.chamberText + (scatterOn ? "" : ", part acoustically invisible")
        if shape == "tetra" {
            // Three on the support touching one another; the fourth touching all three.
            let base = placed.prefix(3).allSatisfy { abs($0.p.z - (zs + a)) < 5e-6 }
            ok = misses == 0 && placed.count == 4 && base && touching.count == 4
                && touching[1] == 1 && touching[2] == 2 && touching[3] == 3 && worstGap < 30e-6
            gate = GateResult(id: "G-B2", name: "a tetrahedron between the open-air plates: three PLA beads touching on the support, a fourth resting on all three",
                              measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                              detail: String(format: "%@; %d/4 placed; base on the support: %@; top touches %d of 3; worst gap %.1f µm; placed beads pushed ≤ %.2f × weight",
                                             how, placed.count, base ? "yes" : "no", touching.count == 4 ? touching[3] : 0,
                                             worstGap * 1e6, worstPush))
        } else {
            let onSupport = placed.filter { abs($0.p.z - (zs + a)) < 5e-6 }.count
            ok = misses == 0 && onSupport == N && worstGap < 30e-6
            gate = GateResult(id: "G-B1", name: "first build between the open-air plates: \(N) PLA beads in a row on the support, touching (|gap| < 30 µm), none lost or perched",
                              measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                              detail: String(format: "%@; %d/%d placed on the support; worst gap %.1f µm; placed beads pushed ≤ %.2f × weight afterwards",
                                             how, onSupport, N, worstGap * 1e6, worstPush))
        }
        print(gate.line)
        print(String(format: "build time %.1f s (simulated); (%.1fs)", t, Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            let tag = "_" + arr.tag + (shape == "row" ? "" : "_" + shape)
            writeReceipt(Receipt(name: (shape == "row" ? "build" : "build-" + shape) + "-" + arr.tag, gates: [gate],
                                 durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
            var fin = "bead,x_mm,y_mm,z_mm,site_x_mm,site_y_mm,on\n"
            for (k, b) in placed.enumerated() {
                fin += String(format: "%d,%.4f,%.4f,%.4f,%.4f,%.4f,%d\n", k, (b.p.x - w0.x) * 1000, (b.p.y - w0.y) * 1000,
                              (b.p.z - w0.z) * 1000, (b.site.x - w0.x) * 1000, (b.site.y - w0.y) * 1000, b.on)
            }
            try? csv.write(toFile: "Receipts/build\(tag)_trajectories.csv", atomically: true, encoding: .utf8)
            try? fin.write(toFile: "Receipts/build\(tag)_placed.csv", atomically: true, encoding: .utf8)
        }
        return ok ? 0 : 1
    }
}
