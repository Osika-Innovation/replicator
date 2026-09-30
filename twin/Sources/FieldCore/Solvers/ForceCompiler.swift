import Foundation

/// Compile for FORCE, not pressure (reviews of 2026-09-29).
///
/// For a small sphere the time-averaged Gor'kov potential at x is a quadratic
/// form in each tone's gate drive g_f:
///
///     U(x) = Σ_f g_fᴴ K_f(x) g_f,    K = K1·a*aᵀ − K2·Σ_j b_j* b_jᵀ,
///
/// with a the gate row of p at x and b_j the gate rows of ∂p/∂x_j. (Tones at
/// different frequencies add because their cross terms average out over the
/// beat period; the chord is incommensurate at the grain's time scale.) The
/// depth of a well at x — the mean of U on a small shell around x minus U(x)
/// — is then also a quadratic form, gᴴ A(x) g. So the compiler can ask for
/// what holding matter needs: one deep well at the target, and every other
/// well in the probe volume shallow. The GS-PAT twin trap only asks for a
/// pressure null, which a resonator satisfies at every node of a column.
///
/// Rows come in from outside (the GPU port-field build with gradients), so
/// FieldCore stays GPU-free.
public enum ForceCompiler {

    /// One tone's gate rows over the probe lattice: rows[(n·G + g)·4 + c],
    /// c = 0 → p, 1…3 → ∂p/∂x, ∂p/∂y, ∂p/∂z.
    public struct Tone: Sendable {
        public var frequency: Double
        public var medium: Medium
        public var rows: [Complex]
        public init(frequency: Double, medium: Medium, rows: [Complex]) {
            self.frequency = frequency; self.medium = medium; self.rows = rows
        }
    }

    public struct Options: Sendable {
        /// Shell radius for the depth measure, in lattice steps (~λ/4).
        public var shellSteps = 3
        /// A competing well deeper than eta × the target counts as a sibling.
        public var eta = 0.5
        /// Penalty weight on sibling depth.
        public var penalty = 4.0
        public var outerIterations = 8
        public var innerIterations = 60
        public var step = 0.15
        /// How many of the deepest competing wells enter the penalty.
        public var siblingsPenalised = 24
        /// Adam iterations of the all-wells refinement (`smooth`); 0 = off.
        public var smoothIterations = 240
        /// For a chord, first compile every tone alone (with this many
        /// `smooth` iterations) and start from their sum. Off for warm
        /// re-compiles, which start from the last drive.
        public var perToneStarts = true
        public var perToneIterations = 100
        /// How far the target well may sit from the requested point (m); nil
        /// = λ/8. `evaluate` still finds the well within λ/4 and reports the
        /// offset; the compiler prefers results inside this radius, and the
        /// smooth refinement treats a well outside it as "no target yet".
        public var placement: Double? = nil
        public init() {}
    }

    public struct Result: Sendable {
        /// Per-tone drives, total power Σ|g|² = 1 (drive units are not SI yet).
        public var drives: [[Complex]]
        /// Well depth at the target (J per unit drive power, relative).
        public var targetDepth: Double
        /// Deepest competing well / target well. < 0.5 = a unique trap.
        public var siblingRatio: Double
        /// Competing wells deeper than eta × the target.
        public var siblings: Int
        /// Target well's distance from the requested point (m); ∞ if no well.
        public var targetOffset: Double
        public var targetWell: Vec3?
    }

    // MARK: - Quadratic forms

    /// K1, K2 of U = K1|p|² − K2|∇p|² for this particle in this medium
    /// (the Bruus 2012 form `Gorkov` uses).
    public static func coefficients(particle: ParticleMaterial, medium: Medium,
                                    frequency: Double) -> (Double, Double) {
        let a = particle.radius
        let kappa0 = 1 / (medium.density * medium.soundSpeed * medium.soundSpeed)
        let kappaP = 1 / (particle.density * particle.soundSpeed * particle.soundSpeed)
        let f1 = 1 - kappaP / kappa0
        let f2 = 2 * (particle.density - medium.density) / (2 * particle.density + medium.density)
        let omega = 2 * Double.pi * frequency
        return (Double.pi * pow(a, 3) * f1 * kappa0 / 3,
                Double.pi * pow(a, 3) * f2 / (2 * omega * omega * medium.density))
    }

    /// U at every probe point for a set of per-tone drives.
    public static func potential(_ tones: [Tone], drives: [[Complex]], gates G: Int,
                                 particle: ParticleMaterial, count: Int) -> [Double] {
        var U = [Double](repeating: 0, count: count)
        for (fi, t) in tones.enumerated() {
            let (k1, k2) = coefficients(particle: particle, medium: t.medium, frequency: t.frequency)
            let g = drives[fi]
            t.rows.withUnsafeBufferPointer { r in
                U.withUnsafeMutableBufferPointer { u in
                    // Chunked, and no per-point heap arrays: this runs every
                    // step of every refinement.
                    let chunks = max(1, min(256, count / 512))
                    DispatchQueue.concurrentPerform(iterations: chunks) { ch in
                        for n in (ch * count / chunks)..<((ch + 1) * count / chunks) {
                            var s0 = Complex.zero, s1 = Complex.zero, s2 = Complex.zero, s3 = Complex.zero
                            let base = n * G * 4
                            for gi in 0..<G {
                                let d = g[gi], b = base + gi * 4
                                s0 += r[b] * d; s1 += r[b + 1] * d; s2 += r[b + 2] * d; s3 += r[b + 3] * d
                            }
                            u[n] += k1 * s0.magnitudeSquared
                                - k2 * (s1.magnitudeSquared + s2.magnitudeSquared + s3.magnitudeSquared)
                        }
                    }
                }
            }
        }
        return U
    }

    /// Hermitian K (G×G, row-major) at one probe point for one tone.
    static func kMatrix(_ t: Tone, point n: Int, gates G: Int, particle: ParticleMaterial) -> [Complex] {
        let (k1, k2) = coefficients(particle: particle, medium: t.medium, frequency: t.frequency)
        var K = [Complex](repeating: .zero, count: G * G)
        let base = n * G * 4
        for i in 0..<G {
            for j in 0..<G {
                var v = t.rows[base + i * 4].conjugate * t.rows[base + j * 4] * k1
                for c in 1...3 {
                    v -= t.rows[base + i * 4 + c].conjugate * t.rows[base + j * 4 + c] * k2
                }
                K[i * G + j] = v
            }
        }
        return K
    }

    /// Depth form A(x) = mean(K on the six shell points) − K(x), per tone.
    static func depthForm(_ tones: [Tone], lattice lat: FieldLattice, at ijk: (Int, Int, Int),
                          steps s: Int, gates G: Int, particle: ParticleMaterial) -> [[Complex]] {
        let (i, j, k) = ijk
        let shell = [(i - s, j, k), (i + s, j, k), (i, j - s, k), (i, j + s, k), (i, j, k - s), (i, j, k + s)]
        return tones.map { t in
            var A = kMatrix(t, point: lat.index(i, j, k), gates: G, particle: particle).map { $0 * -1.0 }
            for (a, b, c) in shell {
                let Ks = kMatrix(t, point: lat.index(a, b, c), gates: G, particle: particle)
                for q in 0..<(G * G) { A[q] += Ks[q] * (1.0 / 6) }
            }
            return A
        }
    }

    static func form(_ A: [[Complex]], _ g: [[Complex]], _ G: Int) -> Double {
        var v = 0.0
        for f in A.indices {
            for i in 0..<G {
                var row = Complex.zero
                for j in 0..<G { row += A[f][i * G + j] * g[f][j] }
                v += (g[f][i].conjugate * row).re
            }
        }
        return v
    }

    static func apply(_ A: [[Complex]], _ g: [[Complex]], _ G: Int) -> [[Complex]] {
        A.indices.map { f in
            (0..<G).map { i in
                var row = Complex.zero
                for j in 0..<G { row += A[f][i * G + j] * g[f][j] }
                return row
            }
        }
    }

    static func normalize(_ g: [[Complex]]) -> [[Complex]] {
        let p = g.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }
        let s = p > 0 ? 1 / p.squareRoot() : 1
        return g.map { $0.map { $0 * s } }
    }

    // MARK: - Wells

    public struct Well: Sendable {
        public var ijk: (Int, Int, Int)
        public var position: Vec3
        public var depth: Double
    }

    /// Local minima of U (6-neighbour) with their shell depth, deepest first.
    public static func wells(_ U: [Double], lattice lat: FieldLattice, steps s: Int) -> [Well] {
        guard lat.nx > 2 * s + 1, lat.ny > 2 * s + 1, lat.nz > 2 * s + 1 else { return [] }
        let sx = 1, sy = lat.nx, sz = lat.nx * lat.ny
        let ks = Array(s..<(lat.nz - s))
        var slices = [[Well]](repeating: [], count: ks.count)
        U.withUnsafeBufferPointer { u in
            slices.withUnsafeMutableBufferPointer { out in
                DispatchQueue.concurrentPerform(iterations: ks.count) { q in
                    let k = ks[q]
                    var found: [Well] = []
                    for j in s..<(lat.ny - s) {
                        for i in s..<(lat.nx - s) {
                            let n = lat.index(i, j, k), c = u[n]
                            guard u[n - sx] > c, u[n + sx] > c, u[n - sy] > c, u[n + sy] > c,
                                  u[n - sz] > c, u[n + sz] > c else { continue }
                            let d = (u[n - s * sx] + u[n + s * sx] + u[n - s * sy] + u[n + s * sy]
                                     + u[n - s * sz] + u[n + s * sz]) / 6 - c
                            guard d > 0 else { continue }
                            // Sub-grid position: a parabola through each axis's three samples.
                            func off(_ a: Double, _ b: Double) -> Double {
                                let den = a - 2 * c + b
                                return den > 0 ? 0.5 * (a - b) / den : 0
                            }
                            let pos = lat.position(i, j, k) + Vec3(off(u[n - sx], u[n + sx]), off(u[n - sy], u[n + sy]),
                                                                   off(u[n - sz], u[n + sz])) * lat.spacing
                            found.append(Well(ijk: (i, j, k), position: pos, depth: d))
                        }
                    }
                    out[q] = found
                }
            }
        }
        return slices.flatMap { $0 }.sorted { $0.depth > $1.depth }
    }

    /// Score a set of drives: the well nearest the target (within λ/4) against
    /// every other well in the probe volume.
    public static func evaluate(_ tones: [Tone], drives: [[Complex]], lattice lat: FieldLattice,
                                target: Vec3, gates G: Int, particle: ParticleMaterial,
                                options o: Options = Options(), wavelength: Double) -> Result {
        let U = potential(tones, drives: drives, gates: G, particle: particle, count: lat.count)
        return evaluate(potential: U, drives: drives, lattice: lat, target: target, options: o,
                        wavelength: wavelength)
    }

    /// The same score from a potential already summed (tones streamed one at
    /// a time, so a 100-tone chord never holds 100 row sets at once).
    public static func evaluate(potential U: [Double], drives: [[Complex]], lattice lat: FieldLattice,
                                target: Vec3, options o: Options = Options(),
                                wavelength: Double) -> Result {
        let ws = wells(U, lattice: lat, steps: o.shellSteps)
        let near = ws.filter { ($0.position - target).length <= wavelength / 4 }
            .min { ($0.position - target).length < ($1.position - target).length }
        guard let t = near else {
            return Result(drives: drives, targetDepth: 0, siblingRatio: .infinity,
                          siblings: ws.count, targetOffset: .infinity, targetWell: nil)
        }
        let others = ws.filter { ($0.position - t.position).length > wavelength / 4 }
        let top = others.first?.depth ?? 0
        return Result(drives: drives, targetDepth: t.depth, siblingRatio: top / t.depth,
                      siblings: others.filter { $0.depth >= o.eta * t.depth }.count,
                      targetOffset: (t.position - target).length, targetWell: t.position)
    }

    // MARK: - Compile

    /// Force-compile one trap at the probe lattice's centre point.
    ///
    /// - Parameter starts: extra starting drives (e.g. the GS-PAT twin trap, or
    ///   the previous solution when re-compiling after the room warmed — the
    ///   continuous-calibration loop). The eigenvector start is always tried;
    ///   the best result over all starts is returned.
    public static func compile(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                               particle: ParticleMaterial, wavelength: Double,
                               options o: Options = Options(),
                               starts: [[[Complex]]] = [],
                               target t: (Int, Int, Int)? = nil) -> Result {
        let c = t ?? ((lat.nx - 1) / 2, (lat.ny - 1) / 2, (lat.nz - 1) / 2)
        let target = lat.position(c.0, c.1, c.2)
        let place = o.placement ?? wavelength / 8
        // Prefer a result whose well sits on the point; then the usual score.
        func better(_ a: Result, _ b: Result) -> Bool {
            let pa = a.targetOffset <= place, pb = b.targetOffset <= place
            if pa != pb { return pa }
            return score(a) > score(b)
        }
        let A0 = depthForm(tones, lattice: lat, at: c, steps: o.shellSteps, gates: G, particle: particle)
        // Eigenvector start: each tone's deepest-well direction, power ∝ its eigenvalue.
        let eig = A0.map { topEigenvector($0, G) }
        let lam = zip(A0, eig).map { max(0, form([$0.0], [$0.1], G)) }
        let tot = lam.reduce(0, +)
        let eigStart = normalize(zip(eig, lam).map { v, l in v.map { $0 * (tot > 0 ? (l / tot).squareRoot() : 1) } })
        var best: Result? = nil
        for start in [eigStart] + starts.map(normalize) {
            let r = refine(tones, lattice: lat, gates: G, particle: particle, wavelength: wavelength,
                           options: o, target: target, A0: A0, start: start)
            if best == nil || better(r, best!) { best = r }
        }
        // Then every probe point at once, from the best so far and from the
        // eigenvector start.
        if o.smoothIterations > 0 {
            var starts2 = [best!.drives, eigStart]
            // A chord: first compile every tone alone, then sum them at equal
            // power. Each tone's siblings sit in its own places, so they add
            // like noise while the target adds in step — the start a joint
            // refinement needs (from an equal-power GS-PAT chord it cannot
            // even find the best single tone, which is always available).
            if tones.count > 1 && o.perToneStarts {
                var solo = o
                solo.smoothIterations = o.perToneIterations
                let each = tones.map { tn in
                    compile([tn], lattice: lat, gates: G, particle: particle, wavelength: wavelength,
                            options: solo, target: c)
                }
                starts2.append(normalize(each.map { $0.drives[0] }))
                // Weighted by how well each tone traps alone (a tone with no
                // well at the target gets nothing), and the best tone alone —
                // so a chord never scores worse than its best member.
                let q = each.map { $0.siblingRatio.isFinite && $0.targetDepth > 0 ? 1 / ($0.siblingRatio * $0.siblingRatio) : 0 }
                let qs = q.reduce(0, +)
                if qs > 0 {
                    starts2.append(normalize(zip(each, q).map { r, w in r.drives[0].map { $0 * (w / qs).squareRoot() } }))
                    let bi = q.indices.max { q[$0] < q[$1] }!
                    let solo = each.indices.map { $0 == bi ? each[$0].drives[0] : [Complex](repeating: .zero, count: G) }
                    let rs = evaluate(tones, drives: normalize(solo), lattice: lat, target: target, gates: G,
                                      particle: particle, options: o, wavelength: wavelength)
                    if better(rs, best!) { best = rs }
                }
            }
            for start in starts2 {
                let r = smooth(tones, lattice: lat, gates: G, particle: particle, wavelength: wavelength,
                               options: o, target: target, center: c, start: start,
                               iterations: o.smoothIterations)
                if better(r, best!) { best = r }
            }
        }
        return best!
    }

    static func refine(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                       particle: ParticleMaterial, wavelength: Double, options o: Options,
                       target: Vec3, A0: [[Complex]], start: [[Complex]]) -> Result {
        var g = start
        var best = evaluate(tones, drives: g, lattice: lat, target: target, gates: G,
                            particle: particle, options: o, wavelength: wavelength)
        for _ in 0..<o.outerIterations {
            // Siblings under the current drive: the deepest competing wells.
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let sib = wells(U, lattice: lat, steps: o.shellSteps)
                .filter { ($0.position - target).length > wavelength / 4 }
                .prefix(o.siblingsPenalised)
            let As = sib.map { depthForm(tones, lattice: lat, at: $0.ijk, steps: o.shellSteps,
                                         gates: G, particle: particle) }
            let scale = max(abs(form(A0, g, G)), 1e-300)
            var step = o.step
            for _ in 0..<o.innerIterations {
                let d0 = form(A0, g, G)
                var grad = apply(A0, g, G)
                for A in As {
                    let x = (form(A, g, G) - o.eta * d0) / scale
                    let w = o.penalty / (1 + exp(-x))                  // softplus' = logistic
                    let ag = apply(A, g, G), a0g = apply(A0, g, G)
                    for f in grad.indices {
                        for i in 0..<G { grad[f][i] -= (ag[f][i] - a0g[f][i] * o.eta) * w }
                    }
                }
                let gn = grad.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }.squareRoot()
                guard gn > 0 else { break }
                g = normalize(zip(g, grad).map { gf, df in zip(gf, df).map { $0 + $1 * (step / gn) } })
                step *= 0.97
            }
            let r = evaluate(tones, drives: g, lattice: lat, target: target, gates: G,
                             particle: particle, options: o, wavelength: wavelength)
            if score(r) > score(best) { best = r }
        }
        return best
    }

    // MARK: - Smooth refinement over every probe point

    /// Wirtinger gradient ∂/∂g_f* of Σ_x c(x) U(x) for every tone: one pass
    /// over the points where c ≠ 0 (U is Σ_f g_fᴴ K_f(x) g_f, so the gradient
    /// is Σ_x c(x) K_f(x) g_f, assembled from the rows without forming K).
    static func adjoint(_ tones: [Tone], drives g: [[Complex]], weights c: [Double], gates G: Int,
                        particle: ParticleMaterial) -> [[Complex]] {
        let active = c.indices.filter { c[$0] != 0 }
        let chunks = max(1, min(64, active.count / 256))
        return tones.enumerated().map { fi, t in
            let (k1, k2) = coefficients(particle: particle, medium: t.medium, frequency: t.frequency)
            let gf = g[fi]
            var partial = [[Complex]](repeating: [Complex](repeating: .zero, count: G), count: chunks)
            t.rows.withUnsafeBufferPointer { r in
                partial.withUnsafeMutableBufferPointer { pb in
                    DispatchQueue.concurrentPerform(iterations: chunks) { ch in
                        var acc = [Complex](repeating: .zero, count: G)
                        let lo = ch * active.count / chunks, hi = (ch + 1) * active.count / chunks
                        for idx in lo..<hi {
                            let n = active[idx], w = c[n], base = n * G * 4
                            var s = (Complex.zero, Complex.zero, Complex.zero, Complex.zero)
                            for gi in 0..<G {
                                let d = gf[gi], b = base + gi * 4
                                s.0 += r[b] * d; s.1 += r[b + 1] * d; s.2 += r[b + 2] * d; s.3 += r[b + 3] * d
                            }
                            let a0 = s.0 * (w * k1), a1 = s.1 * (w * k2), a2 = s.2 * (w * k2), a3 = s.3 * (w * k2)
                            for gi in 0..<G {
                                let b = base + gi * 4
                                acc[gi] += r[b].conjugate * a0 - r[b + 1].conjugate * a1
                                    - r[b + 2].conjugate * a2 - r[b + 3].conjugate * a3
                            }
                        }
                        pb[ch] = acc
                    }
                }
            }
            return (0..<G).map { gi in partial.reduce(Complex.zero) { $0 + $1[gi] } }
        }
    }

    /// Minimise (soft maximum of every competing point's shell depth) ÷ (the
    /// target's shell depth) on the unit sphere of drives, with Adam.
    ///
    /// Every well in the probe volume outside λ/4 of the target is a rival,
    /// re-found each step, so nothing is left for a whack-a-mole list to miss
    /// (the heuristic `refine` penalises the 24 deepest, which with hundreds of
    /// speckle wells in a glass chamber returned its start unchanged — with
    /// five tones it scored worse than one tone can, which no optimum can).
    /// The soft maximum is a softmax-weighted mean at a temperature annealed
    /// from 10 % to 1 % of the target depth. (A first version took every
    /// probe POINT as a rival; curvature on slopes then drowned the wells.)
    static func smooth(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                       particle: ParticleMaterial, wavelength: Double, options o: Options,
                       target: Vec3, center c: (Int, Int, Int), start: [[Complex]],
                       iterations: Int) -> Result {
        let s = o.shellSteps
        let nx = lat.nx, ny = lat.ny
        let ci = lat.index(c.0, c.1, c.2)
        let place = o.placement ?? wavelength / 8
        func better(_ a: Result, _ b: Result) -> Bool {
            let pa = a.targetOffset <= place, pb = b.targetOffset <= place
            if pa != pb { return pa }
            return score(a) > score(b)
        }
        let strides = [1, nx, nx * ny]
        func depth(_ U: [Double], _ n: Int) -> Double {
            var m = 0.0
            for st in strides { m += U[n - s * st] + U[n + s * st] }
            return m / 6 - U[n]
        }
        func spread(_ c: inout [Double], _ n: Int, _ w: Double) {
            c[n] -= w
            for st in strides { c[n - s * st] += w / 6; c[n + s * st] += w / 6 }
        }
        var g = normalize(start)
        var best = evaluate(tones, drives: g, lattice: lat, target: target, gates: G,
                            particle: particle, options: o, wavelength: wavelength)
        // Adam on the real and imaginary parts.
        var m1 = g.map { $0.map { _ in Complex.zero } }, v2 = g.map { $0.map { _ in 0.0 } }
        let b1 = 0.9, b2 = 0.999
        // Adam moves every real coordinate by ~lr, so the step's length grows
        // like √(dimension): scale it to the unit sphere's size.
        let lr0 = 0.05 / Double(2 * G * tones.count).squareRoot()
        for it in 1...iterations {
            let lr = lr0 * (1 - 0.9 * Double(it - 1) / Double(iterations))
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            // Score what `evaluate` scores: the target is the well nearest the
            // requested point (within λ/4), its rivals are the other WELLS —
            // points of positive curvature on a slope are not rivals.
            let ws = wells(U, lattice: lat, steps: s)
            let tw = ws.filter { ($0.position - target).length <= place }
                .min { ($0.position - target).length < ($1.position - target).length }
            let ti = tw.map { lat.index($0.ijk.0, $0.ijk.1, $0.ijk.2) } ?? ci
            let rivals = ws.filter { ($0.position - (tw?.position ?? target)).length > wavelength / 4 }
                .map { lat.index($0.ijk.0, $0.ijk.1, $0.ijk.2) }
            let d0 = depth(U, ti)
            var cw = [Double](repeating: 0, count: lat.count)
            if d0 <= 0 || rivals.isEmpty {
                spread(&cw, ti, -1)                         // make (or deepen) the target well
            } else {
                let comp = rivals
                var mx = -Double.infinity
                var D = [Double](repeating: 0, count: comp.count)
                for (q, n) in comp.enumerated() { D[q] = depth(U, n); mx = max(mx, D[q]) }
                let T = d0 * (0.1 * pow(0.1, Double(it) / Double(iterations)))
                var Z = 0.0, sm = 0.0
                var w = [Double](repeating: 0, count: comp.count)
                for q in comp.indices where D[q] > mx - 30 * T {
                    w[q] = exp((D[q] - mx) / T); Z += w[q]
                }
                for q in comp.indices where w[q] > 0 { w[q] /= Z; sm += w[q] * D[q] }
                // ∂(sm/d0) = (∂sm·d0 − sm·∂d0)/d0²; ∂sm/∂D_q = w_q (1 + (D_q − sm)/T)
                for (q, n) in comp.enumerated() where w[q] > 1e-12 {
                    spread(&cw, n, w[q] * (1 + (D[q] - sm) / T) / d0)
                }
                spread(&cw, ti, -sm / (d0 * d0))
            }
            var grad = adjoint(tones, drives: g, weights: cw, gates: G, particle: particle)
            // Adam sees the gradient's direction only: a Gor'kov potential is ∝ a³, so for
            // fine powder the raw gradients are ~1e-20 and Adam's ε would stall every step.
            let gn = grad.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }.squareRoot()
            if gn > 0 { grad = grad.map { $0.map { $0 * (1 / gn) } } }
            // Adam step, descent; back onto the unit sphere.
            for f in g.indices {
                for i in 0..<G {
                    let gr = grad[f][i]
                    m1[f][i] = m1[f][i] * b1 + gr * (1 - b1)
                    v2[f][i] = v2[f][i] * b2 + gr.magnitudeSquared * (1 - b2)
                    let mh = m1[f][i] * (1 / (1 - pow(b1, Double(it))))
                    let vh = v2[f][i] / (1 - pow(b2, Double(it)))
                    g[f][i] -= mh * (lr / (vh.squareRoot() + 1e-12))
                }
            }
            g = normalize(g)
            if it % 20 == 0 || it == iterations {
                let r = evaluate(tones, drives: g, lattice: lat, target: target, gates: G,
                                 particle: particle, options: o, wavelength: wavelength)
                if better(r, best) { best = r }
            }
        }
        return best
    }

    // MARK: - An acoustic mold: many wells at once

    public struct Mold: Sendable {
        /// Per-tone drives, total power Σ|g|² = 1.
        public var drives: [[Complex]]
        /// Each target's shell depth (J per unit drive power); ≤ 0: no well there.
        public var depths: [Double]
        /// Deepest rival well (outside every target's λ/8) over the shallowest target.
        public var rivalRatio: Double
        /// Targets with a well within λ/8.
        public var formed: Int
    }

    /// Score a mold: every target should be a well, and no other well should
    /// come near the shallowest of them.
    public static func evaluateMold(_ U: [Double], lattice lat: FieldLattice, targets: [(Int, Int, Int)],
                                    options o: Options, wavelength: Double) -> (depths: [Double], rivalRatio: Double, formed: Int) {
        let ws = wells(U, lattice: lat, steps: o.shellSteps)
        let tp = targets.map { lat.position($0.0, $0.1, $0.2) }
        let s = o.shellSteps
        let axes = [1, lat.nx, lat.nx * lat.ny]
        let depths = targets.map { t -> Double in
            let n = lat.index(t.0, t.1, t.2)
            var m = 0.0
            for st in axes { m += U[n - s * st] + U[n + s * st] }
            return m / 6 - U[n]
        }
        let formed = tp.filter { p in ws.contains { ($0.position - p).length <= wavelength / 8 } }.count
        let rivals = ws.filter { w in !tp.contains { ($0 - w.position).length <= wavelength / 4 } }
        let weakest = max(depths.min() ?? 0, 1e-300)
        return (depths, (rivals.first?.depth ?? 0) / weakest, formed)
    }

    /// Compile a mold: one drive whose potential has a well at every target and
    /// as few others as possible. Adam on the drives, minimising
    /// softmax(rival well depths) / softmin(target depths) — the single-trap
    /// `smooth` objective with the target term generalised to many.
    public static func compileMold(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                                   particle: ParticleMaterial, targets: [(Int, Int, Int)], wavelength: Double,
                                   options o: Options = Options(), start: [[Complex]],
                                   iterations: Int = 300, log: ((String) -> Void)? = nil) -> Mold {
        let s = o.shellSteps
        let axes = [1, lat.nx, lat.nx * lat.ny]
        let tIdx = targets.map { lat.index($0.0, $0.1, $0.2) }
        let tPos = targets.map { lat.position($0.0, $0.1, $0.2) }
        func depth(_ U: [Double], _ n: Int) -> Double {
            var m = 0.0
            for st in axes { m += U[n - s * st] + U[n + s * st] }
            return m / 6 - U[n]
        }
        func spread(_ c: inout [Double], _ n: Int, _ w: Double) {
            c[n] -= w
            for st in axes { c[n - s * st] += w / 6; c[n + s * st] += w / 6 }
        }
        var g = normalize(start)
        func score(_ U: [Double]) -> (Mold, Double) {
            let e = evaluateMold(U, lattice: lat, targets: targets, options: o, wavelength: wavelength)
            let m = Mold(drives: g, depths: e.depths, rivalRatio: e.rivalRatio, formed: e.formed)
            // Prefer every target formed; then a low rival ratio.
            return (m, Double(e.formed) - min(e.rivalRatio, 50) / 100)
        }
        var (best, bestScore) = score(potential(tones, drives: g, gates: G, particle: particle, count: lat.count))
        var m1 = g.map { $0.map { _ in Complex.zero } }, v2 = g.map { $0.map { _ in 0.0 } }
        let b1 = 0.9, b2 = 0.999
        let lr0 = 0.05 / Double(2 * G * tones.count).squareRoot()
        for it in 1...iterations {
            let lr = lr0 * (1 - 0.9 * Double(it - 1) / Double(iterations))
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let D = tIdx.map { depth(U, $0) }
            var cw = [Double](repeating: 0, count: lat.count)
            let dMin = D.min()!
            if dMin <= 0 {
                // First make every target a well: deepen the ones that are not.
                for (q, n) in tIdx.enumerated() where D[q] <= 0 { spread(&cw, n, -1) }
            } else {
                // Soft minimum over the targets.
                let Tt = 0.1 * dMin
                let et = D.map { exp(-($0 - dMin) / Tt) }, zt = et.reduce(0, +)
                let wt = et.map { $0 / zt }
                let smin = zip(wt, D).reduce(0) { $0 + $1.0 * $1.1 }
                // Soft maximum over the rival wells.
                let rivals = wells(U, lattice: lat, steps: s).filter { w in !tPos.contains { ($0 - w.position).length <= wavelength / 4 } }
                    .map { lat.index($0.ijk.0, $0.ijk.1, $0.ijk.2) }
                if rivals.isEmpty {
                    for (q, n) in tIdx.enumerated() { spread(&cw, n, -wt[q] * (1 - (D[q] - smin) / Tt) / smin) }
                } else {
                    let R = rivals.map { depth(U, $0) }
                    let mx = R.max()!
                    let Tr = smin * (0.1 * pow(0.1, Double(it) / Double(iterations)))
                    var w = R.map { $0 > mx - 30 * Tr ? exp(($0 - mx) / Tr) : 0 }
                    let Z = w.reduce(0, +)
                    w = w.map { $0 / Z }
                    let sm = zip(w, R).reduce(0) { $0 + $1.0 * $1.1 }
                    // r = sm / smin: ∂r = ∂sm/smin − sm ∂smin/smin²
                    for (q, n) in rivals.enumerated() where w[q] > 1e-12 {
                        spread(&cw, n, w[q] * (1 + (R[q] - sm) / Tr) / smin)
                    }
                    for (q, n) in tIdx.enumerated() {
                        spread(&cw, n, -sm / (smin * smin) * wt[q] * (1 - (D[q] - smin) / Tt))
                    }
                }
                // Centring: a target with depth is not yet a well ON its point — its
                // minimum can sit a millimetre off. + μ Σ_t Σ_j slope²/d_t², slope_j the
                // one-step difference across the target.
                let mu = 2.0
                for (q, n) in tIdx.enumerated() where D[q] > 0 {
                    var sl2 = 0.0
                    for st in axes {
                        let sl = (U[n + st] - U[n - st]) / 2
                        sl2 += sl * sl
                        cw[n + st] += mu * sl / (D[q] * D[q])
                        cw[n - st] -= mu * sl / (D[q] * D[q])
                    }
                    spread(&cw, n, -2 * mu * sl2 / (D[q] * D[q] * D[q]))
                }
            }
            var grad = adjoint(tones, drives: g, weights: cw, gates: G, particle: particle)
            let gn = grad.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }.squareRoot()
            if gn > 0 { grad = grad.map { $0.map { $0 * (1 / gn) } } }
            for f in g.indices {
                for i in 0..<G {
                    let gr = grad[f][i]
                    m1[f][i] = m1[f][i] * b1 + gr * (1 - b1)
                    v2[f][i] = v2[f][i] * b2 + gr.magnitudeSquared * (1 - b2)
                    let mh = m1[f][i] * (1 / (1 - pow(b1, Double(it))))
                    let vh = v2[f][i] / (1 - pow(b2, Double(it)))
                    g[f][i] -= mh * (lr / (vh.squareRoot() + 1e-12))
                }
            }
            g = normalize(g)
            if it % 20 == 0 || it == iterations {
                let (m, sc) = score(potential(tones, drives: g, gates: G, particle: particle, count: lat.count))
                if sc > bestScore { best = m; bestScore = sc }
                if let log, it % 60 == 0 {
                    let pos = m.depths.filter { $0 > 0 }.count
                    log(String(format: "    it %d: %d/%d formed, %d/%d positive depth, depth %.2e…%.2e, rival/weakest %.2f",
                               it, m.formed, targets.count, pos, targets.count, m.depths.min() ?? 0, m.depths.max() ?? 0,
                               min(m.rivalRatio, 1e6)))
                }
            }
        }
        return best
    }

    // MARK: - A mold that funnels

    public struct Funnel: Sendable {
        /// Per-tone drives, total power Σ|g|² = 1.
        public var drives: [[Complex]]
        /// Share of the release volume (outside the capture radius) where U
        /// falls toward the nearest target.
        public var funnelled: Double
        /// The same on the start drive, for comparison.
        public var funnelledAtStart: Double
    }

    /// Compile a mold for the FLOW, not for its wells. A well at every target
    /// is not enough: powder spread through the volume ends wherever its own
    /// basin leads, and `compileMold`'s rival-well penalty left most of it in
    /// layers a wavelength above and below the targets (`fieldc mold`,
    /// 30 Sep). So ask, at every probe point of the release volume outside the
    /// capture radius, that U fall toward the nearest target:
    ///
    ///     s(x) = ∇U(x) · ∇V(x) > 0,   V = −ℓ log Σ_t exp(−|x − t|/ℓ),
    ///
    /// V the distance to the nearest target, softened over ℓ so a ridge
    /// between two targets asks for nothing. Wherever s > 0 the distance to
    /// the nearest target falls along an overdamped grain's path (a Lyapunov
    /// function), so a grain released there must end in a target, and every
    /// target is a well. The loss is the logistic hinge Σ log(1 + e^(−s/σ)),
    /// σ a quarter of the rms slope; ∇U is the lattice's central difference,
    /// so the loss is a lattice weighting of U and `adjoint` gives its
    /// gradient. Adam on the drives, gradients normalised; the best drive by
    /// funnelled share is returned.
    public static func compileFunnel(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                                     particle: ParticleMaterial, targets: [Vec3], capture: Double,
                                     release: (Vec3) -> Bool, softness ell: Double, start: [[Complex]],
                                     iterations: Int = 300, log: ((String) -> Void)? = nil) -> Funnel {
        let h = lat.spacing
        let axes = [1, lat.nx, lat.nx * lat.ny]
        // The release volume's probe points, and ∇V at each.
        var idx: [Int] = [], dir: [(Double, Double, Double)] = []
        for k in 1..<(lat.nz - 1) {
            for j in 1..<(lat.ny - 1) {
                for i in 1..<(lat.nx - 1) {
                    let x = lat.position(i, j, k)
                    guard release(x) else { continue }
                    let d = targets.map { ($0 - x).length }
                    let dMin = d.min()!
                    guard dMin > capture else { continue }
                    var gv = Vec3(0, 0, 0), z = 0.0
                    for (q, t) in targets.enumerated() {
                        let w = exp(-(d[q] - dMin) / ell)
                        gv = gv + (x - t) * (w / d[q]); z += w
                    }
                    gv = gv * (1 / z)
                    idx.append(lat.index(i, j, k)); dir.append((gv.x, gv.y, gv.z))
                }
            }
        }
        let M = Double(idx.count)
        func slopes(_ U: [Double]) -> [Double] {
            idx.indices.map { m in
                let n = idx[m], v = dir[m]
                return (v.0 * (U[n + axes[0]] - U[n - axes[0]]) + v.1 * (U[n + axes[1]] - U[n - axes[1]])
                        + v.2 * (U[n + axes[2]] - U[n - axes[2]])) / (2 * h)
            }
        }
        func share(_ s: [Double]) -> Double { Double(s.filter { $0 > 0 }.count) / M }
        var g = normalize(start)
        let s0 = share(slopes(potential(tones, drives: g, gates: G, particle: particle, count: lat.count)))
        var best = Funnel(drives: g, funnelled: s0, funnelledAtStart: s0)
        var m1 = g.map { $0.map { _ in Complex.zero } }, v2 = g.map { $0.map { _ in 0.0 } }
        let b1 = 0.9, b2 = 0.999
        let lr0 = 0.05 / Double(2 * G * tones.count).squareRoot()
        for it in 1...iterations {
            let lr = lr0 * (1 - 0.9 * Double(it - 1) / Double(iterations))
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let s = slopes(U)
            let now = share(s)
            if now > best.funnelled { best = Funnel(drives: g, funnelled: now, funnelledAtStart: s0) }
            if let log, it % 50 == 1 { log(String(format: "    it %d: %.1f%% of the release volume funnels", it - 1, 100 * now)) }
            let sigma = 0.25 * (s.reduce(0) { $0 + $1 * $1 } / M).squareRoot()
            guard sigma > 0 else { break }
            var cw = [Double](repeating: 0, count: lat.count)
            for m in idx.indices {
                let q = -1 / (1 + exp(s[m] / sigma)) / (sigma * M * 2 * h)      // ∂L/∂s ÷ 2h
                let n = idx[m], v = dir[m]
                cw[n + axes[0]] += q * v.0; cw[n - axes[0]] -= q * v.0
                cw[n + axes[1]] += q * v.1; cw[n - axes[1]] -= q * v.1
                cw[n + axes[2]] += q * v.2; cw[n - axes[2]] -= q * v.2
            }
            var grad = adjoint(tones, drives: g, weights: cw, gates: G, particle: particle)
            let gn = grad.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }.squareRoot()
            if gn > 0 { grad = grad.map { $0.map { $0 * (1 / gn) } } }
            for f in g.indices {
                for i in 0..<G {
                    let gr = grad[f][i]
                    m1[f][i] = m1[f][i] * b1 + gr * (1 - b1)
                    v2[f][i] = v2[f][i] * b2 + gr.magnitudeSquared * (1 - b2)
                    let mh = m1[f][i] * (1 / (1 - pow(b1, Double(it))))
                    let vh = v2[f][i] / (1 - pow(b2, Double(it)))
                    g[f][i] -= mh * (lr / (vh.squareRoot() + 1e-12))
                }
            }
            g = normalize(g)
        }
        let last = share(slopes(potential(tones, drives: g, gates: G, particle: particle, count: lat.count)))
        if last > best.funnelled { best = Funnel(drives: g, funnelled: last, funnelledAtStart: s0) }
        log?(String(format: "    best: %.1f%% of the release volume funnels (start %.1f%%)", 100 * best.funnelled, 100 * s0))
        return best
    }

    // MARK: - An acoustic sieve

    public struct Sieve: Sendable {
        /// Per-tone drives, total power Σ|g|² = 1.
        public var drives: [[Complex]]
        /// The weakest target's lift over the most any point away from the
        /// targets can lift. > 1: a power window where only targets hold.
        public var contrast: Double
        public var contrastAtStart: Double
    }

    /// Compile a sieve: a field in which ONLY the targets can hold a grain up.
    ///
    /// A still field reaches a grain only within about λ/4 of its lowest tone
    /// (`fieldc mold`: 90% capture from within 2 mm of the ring, none from
    /// beyond 6 mm, whatever the objective — a resonant chamber's landscape
    /// repeats every half wavelength). Gravity reaches everywhere. A grain can
    /// only come to rest where the lift L = −∂U/∂z (per unit power) equals
    /// mg/P, so if every target lifts more than any point away from the
    /// targets, there is a power at which the targets hold and nothing else
    /// can: every other grain falls, and powder sprinkled from above collects
    /// only in the targets. The compiler maximises that contrast — the soft
    /// minimum over targets of the best lift in each target's column (±2
    /// steps) over the soft maximum of the lift everywhere `outside` the
    /// shape's neighbourhood (the targets sample the shape; a grain held
    /// between two of them is still on the shape) — on the unit sphere of
    /// drives, with Adam.
    /// A sideways term keeps every target a well in the horizontal plane, at
    /// its level and one step below (where a held grain sags to): a grain that
    /// lands on the shape then stays at the site it landed on, instead of
    /// sliding along the shape to a few deep spots (without it the powder all
    /// reached the ring but gathered at 8 of 16 sites).
    public static func compileSieve(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                                    particle: ParticleMaterial, targets: [(Int, Int, Int)], outside isOutside: (Vec3) -> Bool,
                                    sideways sw: Int = 2, softness ell: Double = 0.5e-3, options o: Options = Options(),
                                    start: [[Complex]], iterations: Int = 300, log: ((String) -> Void)? = nil) -> Sieve {
        let h = lat.spacing
        let sz = lat.nx * lat.ny
        let axes = [1, lat.nx, sz]
        var outside: [Int] = []
        for k in 1..<(lat.nz - 1) {
            for j in 1..<(lat.ny - 1) {
                for i in 1..<(lat.nx - 1) where isOutside(lat.position(i, j, k)) { outside.append(lat.index(i, j, k)) }
            }
        }
        // A held grain rests where the lift has fallen to its weight, ABOVE the
        // lift's peak. Asking for the lift at the target itself (and one step
        // up) puts the rest point on the target; a column reaching two steps
        // down let the powder hang a millimetre under the ring.
        let columns: [[Int]] = targets.map { t in
            (0...1).compactMap { dk in
                let k = t.2 + dk
                return k >= 1 && k < lat.nz - 1 ? lat.index(t.0, t.1, k) : nil
            }
        }
        let tIdx = targets.map { lat.index($0.0, $0.1, $0.2) }
        let s = o.shellSteps
        func lift(_ U: [Double], _ n: Int) -> Double { -(U[n + sz] - U[n - sz]) / (2 * h) }
        func depth(_ U: [Double], _ n: Int) -> Double {
            var m = 0.0
            for st in axes { m += U[n - s * st] + U[n + s * st] }
            return m / 6 - U[n]
        }
        func measure(_ U: [Double]) -> Double {
            let out = outside.reduce(0.0) { max($0, lift(U, $1)) }
            let tl = columns.map { c in c.reduce(-Double.infinity) { max($0, lift(U, $1)) } }.min() ?? 0
            return tl / max(out, 1e-300)
        }
        // Sideways: at each target's level and one up (where its grains rest),
        // each of the four horizontal neighbours `sw` steps out must lie above
        // the centre — then a minimum sits within ±sw steps of the target, a
        // real trap, where a positive mean depth still allowed a tilt that
        // slid the grain to the next site.
        let levels: [(site: Int, n: Int)] = targets.enumerated().flatMap { q, t in
            [0, 1].compactMap { dk -> (site: Int, n: Int)? in
                let k = t.2 + dk
                guard k >= 1, k < lat.nz - 1, t.0 - sw >= 0, t.0 + sw < lat.nx, t.1 - sw >= 0, t.1 + sw < lat.ny else { return nil }
                return (q, lat.index(t.0, t.1, k))
            }
        }
        let side = [-sw, sw, -sw * lat.nx, sw * lat.nx]
        func held(_ U: [Double]) -> Int {
            // Held at BOTH levels: a held grain rests between them.
            (0..<targets.count).filter { q in
                let ls = levels.filter { $0.site == q }
                return !ls.isEmpty && ls.allSatisfy { lv in side.allSatisfy { U[lv.n + $0] > U[lv.n] } }
            }.count
        }
        // Best: a real window first (contrast > 1.2), then the most sites held sideways, then the contrast.
        func better(_ a: (Double, Int), than b: (Double, Int)) -> Bool {
            let wa = a.0 > 1.2, wb = b.0 > 1.2
            if wa != wb { return wa }
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0 > b.0
        }
        // Landing: where a falling grain is caught — near the shape, off the
        // sites — U must fall sideways toward the nearest site (the funnel of
        // `compileFunnel`, here only across the landing band, where one site's
        // reach covers its share of the shape). Then each site gathers the
        // powder that lands in its own stretch of the shape.
        let tPos = targets.map { lat.position($0.0, $0.1, $0.2) }
        var landing: [(n: Int, v: (Double, Double), site: Int)] = []
        for k in 1..<(lat.nz - 1) {
            for j in 1..<(lat.ny - 1) {
                for i in 1..<(lat.nx - 1) {
                    let x = lat.position(i, j, k)
                    guard !isOutside(x) else { continue }
                    let d = tPos.map { ($0 - x).length }
                    let dMin = d.min()!
                    guard dMin > 1.5 * h else { continue }
                    var gv = Vec3(0, 0, 0), z = 0.0
                    for (q, t) in tPos.enumerated() {
                        let w = exp(-(d[q] - dMin) / ell)
                        gv = gv + (x - t) * (w / d[q]); z += w
                    }
                    landing.append((lat.index(i, j, k), (gv.x / z, gv.y / z), d.firstIndex(of: dMin)!))
                }
            }
        }
        var perSite = [Int](repeating: 0, count: targets.count)
        for l in landing { perSite[l.site] += 1 }
        func landingSlopes(_ U: [Double]) -> [Double] {
            landing.map { l in
                (l.v.0 * (U[l.n + 1] - U[l.n - 1]) + l.v.1 * (U[l.n + lat.nx] - U[l.n - lat.nx])) / (2 * h)
            }
        }
        var g = normalize(start)
        let U0 = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
        let c0 = measure(U0)
        var best = Sieve(drives: g, contrast: c0, contrastAtStart: c0)
        var bestKey = (c0, held(U0))
        var m1 = g.map { $0.map { _ in Complex.zero } }, v2 = g.map { $0.map { _ in 0.0 } }
        let b1 = 0.9, b2 = 0.999
        let lr0 = 0.05 / Double(2 * G * tones.count).squareRoot()
        for it in 1...iterations {
            let lr = lr0 * (1 - 0.9 * Double(it - 1) / Double(iterations))
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            // Soft maximum over the outside (log-sum-exp).
            let Lo = outside.map { lift(U, $0) }
            let mo = Lo.max()!
            let To = max(0.03 * abs(mo), 1e-300)
            let eo = Lo.map { exp(($0 - mo) / To) }, zo = eo.reduce(0, +)
            let smax = mo + To * Foundation.log(zo)
            // Each target's best lift in its column (log-sum-exp), then a soft minimum over targets.
            var colW: [[Double]] = [], colL: [Double] = []
            for c in columns {
                let L = c.map { lift(U, $0) }, m = L.max()!
                let T = max(0.03 * abs(m), 1e-300)
                let e = L.map { exp(($0 - m) / T) }, z = e.reduce(0, +)
                colW.append(e.map { $0 / z }); colL.append(m + T * Foundation.log(z))
            }
            let mt = colL.min()!
            let Tt = max(0.05 * abs(mt), 1e-300)
            let et = colL.map { exp(-($0 - mt) / Tt) }, zt = et.reduce(0, +)
            let smin = mt - Tt * Foundation.log(zt)
            let now = measure(U), hNow = held(U)
            if better((now, hNow), than: bestKey) { best = Sieve(drives: g, contrast: now, contrastAtStart: c0); bestKey = (now, hNow) }
            let ls = landingSlopes(U)
            if let log, it % 50 == 1 {
                let fun = Double(ls.filter { $0 > 0 }.count) / Double(max(ls.count, 1))
                var ok = [Int](repeating: 0, count: targets.count)
                for (m, l) in landing.enumerated() where ls[m] > 0 { ok[l.site] += 1 }
                let worst = targets.indices.filter { perSite[$0] > 0 }.map { Double(ok[$0]) / Double(perSite[$0]) }.min() ?? 0
                log(String(format: "    it %d: contrast %.2f, %d/%d sites held sideways, %.0f%% of the landing band funnels to its site (worst site %.0f%%)",
                           it - 1, now, hNow, targets.count, 100 * fun, 100 * worst))
            }
            // loss = log smax − log smin (+ sideways depth where a target has none).
            var cw = [Double](repeating: 0, count: lat.count)
            func addLift(_ n: Int, _ w: Double) { cw[n + sz] -= w / (2 * h); cw[n - sz] += w / (2 * h) }
            for (q, n) in outside.enumerated() where eo[q] > 1e-12 { addLift(n, eo[q] / zo / smax) }
            if smin > 0 {
                for (t, c) in columns.enumerated() {
                    let wt = et[t] / zt
                    guard wt > 1e-12 else { continue }
                    for (q, n) in c.enumerated() { addLift(n, -wt * colW[t][q] / smin) }
                }
            } else {
                for (t, c) in columns.enumerated() where colL[t] <= 0 {
                    for (q, n) in c.enumerated() { addLift(n, -colW[t][q] / max(smax, 1e-300)) }
                }
            }
            // Sideways: a soft hinge on each neighbour's rise over the centre, in
            // units of the lift a site must give (rise ≥ 0.2·smin·sw·h).
            if smin > 0 {
                let unit = 0.2 * smin * Double(sw) * h, tau = 0.5 * unit
                let per = 1 / (tau * Double(levels.count * side.count))
                for lv in levels {
                    for st in side {
                        let d = U[lv.n + st] - U[lv.n]
                        let q = -per / (1 + exp((d - unit) / tau))
                        cw[lv.n + st] += q; cw[lv.n] -= q
                    }
                }
            }
            if !ls.isEmpty, smin > 0 {
                // Per site, the mean logistic hinge of its stretch of the band; then
                // a soft maximum over the sites, so the worst-served site leads (an
                // average let two sites of sixteen stay empty, run after run).
                let sig = 0.25 * (ls.reduce(0) { $0 + $1 * $1 } / Double(ls.count)).squareRoot()
                if sig > 0 {
                    var loss = [Double](repeating: 0, count: targets.count)
                    for (m, l) in landing.enumerated() {
                        let u = -ls[m] / sig
                        loss[l.site] += (u > 30 ? u : Foundation.log(1 + exp(u))) / Double(perSite[l.site])
                    }
                    let Tl = 0.05
                    let lmax = loss.max()!
                    let el = loss.map { exp(($0 - lmax) / Tl) }, zl = el.reduce(0, +)
                    for (m, l) in landing.enumerated() {
                        let ws = el[l.site] / zl / Double(perSite[l.site])
                        let q = -ws / (1 + exp(ls[m] / sig)) / (sig * 2 * h)
                        cw[l.n + 1] += q * l.v.0; cw[l.n - 1] -= q * l.v.0
                        cw[l.n + lat.nx] += q * l.v.1; cw[l.n - lat.nx] -= q * l.v.1
                    }
                }
            }
            for n in tIdx where depth(U, n) <= 0 {
                // Deepen: −depth, spread over the shell, scaled like the lift terms.
                let w = 1 / max(smax * h, 1e-300)
                cw[n] += w
                for st in axes { cw[n - s * st] -= w / 6; cw[n + s * st] -= w / 6 }
            }
            var grad = adjoint(tones, drives: g, weights: cw, gates: G, particle: particle)
            let gn = grad.reduce(0.0) { $0 + $1.reduce(0.0) { $0 + $1.magnitudeSquared } }.squareRoot()
            if gn > 0 { grad = grad.map { $0.map { $0 * (1 / gn) } } }
            for f in g.indices {
                for i in 0..<G {
                    let gr = grad[f][i]
                    m1[f][i] = m1[f][i] * b1 + gr * (1 - b1)
                    v2[f][i] = v2[f][i] * b2 + gr.magnitudeSquared * (1 - b2)
                    let mh = m1[f][i] * (1 / (1 - pow(b1, Double(it))))
                    let vh = v2[f][i] / (1 - pow(b2, Double(it)))
                    g[f][i] -= mh * (lr / (vh.squareRoot() + 1e-12))
                }
            }
            g = normalize(g)
        }
        let UL = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
        if better((measure(UL), held(UL)), than: bestKey) {
            best = Sieve(drives: g, contrast: measure(UL), contrastAtStart: c0); bestKey = (measure(UL), held(UL))
        }
        log?(String(format: "    best: contrast %.2f, %d/%d sites held sideways (start %.2f)", best.contrast, bestKey.1, targets.count, c0))
        return best
    }

    // MARK: - Moving a trap

    /// Trilinear weights of the 8 lattice points around x.
    static func trilinear(_ lat: FieldLattice, _ x: Vec3) -> [(Int, Double)] {
        let f = (x - lat.origin) / lat.spacing
        let i0 = max(1, min(lat.nx - 3, Int(f.x.rounded(.down))))
        let j0 = max(1, min(lat.ny - 3, Int(f.y.rounded(.down))))
        let k0 = max(1, min(lat.nz - 3, Int(f.z.rounded(.down))))
        let tx = f.x - Double(i0), ty = f.y - Double(j0), tz = f.z - Double(k0)
        var out: [(Int, Double)] = []
        for (dk, wz) in [(0, 1 - tz), (1, tz)] {
            for (dj, wy) in [(0, 1 - ty), (1, ty)] {
                for (di, wx) in [(0, 1 - tx), (1, tx)] {
                    out.append((lat.index(i0 + di, j0 + dj, k0 + dk), wx * wy * wz))
                }
            }
        }
        return out
    }

    /// U at a point between lattice nodes (trilinear).
    public static func interpolate(_ U: [Double], lattice lat: FieldLattice, at x: Vec3) -> Double {
        trilinear(lat, x).reduce(0) { $0 + U[$1.0] * $1.1 }
    }

    /// Move the trap onto x with the smallest change of drive: Newton on
    /// ∇U(x) = 0, with ∇U read off the lattice (central differences,
    /// trilinear between nodes) and each step the minimal-norm solution of
    /// the linearised three equations. A continuation, not a re-compile: the
    /// field changes as little as the move needs, so rivals do not appear from
    /// nowhere, and x can sit between lattice points. (Re-compiling from the
    /// last drive either kept the old well while the target moved away, or
    /// hopped to a different one — `fieldc carry`, 29 Sep.)
    ///
    /// - Parameter balance: an external force per unit drive power (N per
    ///   (m/s)²) the trap must hold at x — gravity is (0, 0, −mg/P). The
    ///   condition becomes ∇U(x) = balance: the bead then RESTS on x, instead
    ///   of sagging below the potential's minimum and sliding sideways along
    ///   its tilted axes (0.5 mm at 4× the holding drive, `fieldc build`).
    public static func moveWell(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                                particle: ParticleMaterial, drives start: [[Complex]], to x: Vec3,
                                iterations: Int = 8, balance: Vec3 = Vec3(0, 0, 0)) -> (drives: [[Complex]], residual: Double) {
        var g = normalize(start)
        let h = lat.spacing
        let axes = [1, lat.nx, lat.nx * lat.ny]
        let corners = trilinear(lat, x)
        // c^(j): the weights that turn U into the interpolated ∂U/∂x_j at x.
        var cj = [[Double]](repeating: [Double](repeating: 0, count: lat.count), count: 3)
        for (j, st) in axes.enumerated() {
            for (n, w) in corners {
                cj[j][n + st] += w / (2 * h)
                cj[j][n - st] -= w / (2 * h)
            }
        }
        var residual = 0.0
        let bal = [balance.x, balance.y, balance.z]
        for _ in 0..<iterations {
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let grad = (0..<3).map { j in cj[j].indices.reduce(0.0) { $0 + (cj[j][$1] == 0 ? 0 : cj[j][$1] * U[$1]) } - bal[j] }
            // Scale: the well's curvature × one lattice step.
            var curv = 0.0
            for (n, w) in corners {
                for st in axes { curv += w * (U[n + st] + U[n - st] - 2 * U[n]) / (h * h) }
            }
            residual = (grad.reduce(0) { $0 + $1 * $1 }).squareRoot() / max(abs(curv) / 3, 1e-300)
            if residual < 1e-6 { break }                     // well within a micrometre of x
            // Real Jacobian rows: ∂G_j/∂Re g = 2 Re w, ∂G_j/∂Im g = 2 Im w, w = ∂G_j/∂g*.
            let W = (0..<3).map { adjoint(tones, drives: g, weights: cj[$0], gates: G, particle: particle) }
            let A: [[Double]] = W.map { w in w.flatMap { $0.flatMap { [2 * $0.re, 2 * $0.im] } } }
            // Minimal-norm step: Δθ = −Aᵀ (A Aᵀ)⁻¹ G.
            var M = [[Double]](repeating: [0, 0, 0], count: 3)
            for a in 0..<3 { for b in 0..<3 { M[a][b] = zip(A[a], A[b]).reduce(0) { $0 + $1.0 * $1.1 } } }
            guard let y = solve3(M, grad) else { break }
            var dtheta = [Double](repeating: 0, count: A[0].count)
            for a in 0..<3 { for q in dtheta.indices { dtheta[q] -= A[a][q] * y[a] } }
            // Damped: never more than a fifth of the drive's norm per step.
            let norm = (dtheta.reduce(0) { $0 + $1 * $1 }).squareRoot()
            if norm > 0.2 { dtheta = dtheta.map { $0 * 0.2 / norm } }
            var q = 0
            for f in g.indices {
                for i in 0..<G {
                    g[f][i] += Complex(dtheta[q], dtheta[q + 1]); q += 2
                }
            }
            g = normalize(g)
        }
        return (g, residual)
    }

    /// One carry step: put the well on x AND keep it the only one. Each
    /// iteration takes a Newton step on ∇U(x) = 0 and a descent step on the
    /// rival ratio (softmax of rival depths over the target's, as `smooth`)
    /// projected onto the constraint's null space — so the rival step does not,
    /// to first order, move the well. (`moveWell` alone places the well to
    /// 0.1 mm but lets the rivals grow: 0.43 → 0.97 in four 0.25 mm steps.)
    public static func carryStep(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                                 particle: ParticleMaterial, wavelength: Double, options o: Options,
                                 drives start: [[Complex]], to x: Vec3,
                                 iterations: Int = 60, balance: Vec3 = Vec3(0, 0, 0)) -> [[Complex]] {
        var g = normalize(start)
        let h = lat.spacing, s = o.shellSteps
        let axes = [1, lat.nx, lat.nx * lat.ny]
        let corners = trilinear(lat, x)
        var cj = [[Double]](repeating: [Double](repeating: 0, count: lat.count), count: 3)
        for (j, st) in axes.enumerated() {
            for (n, w) in corners { cj[j][n + st] += w / (2 * h); cj[j][n - st] -= w / (2 * h) }
        }
        let f = (x - lat.origin) / h
        let ci = lat.index(Int(f.x.rounded()), Int(f.y.rounded()), Int(f.z.rounded()))
        func depth(_ U: [Double], _ n: Int) -> Double {
            var m = 0.0
            for st in axes { m += U[n - s * st] + U[n + s * st] }
            return m / 6 - U[n]
        }
        func spread(_ c: inout [Double], _ n: Int, _ w: Double) {
            c[n] -= w
            for st in axes { c[n - s * st] += w / 6; c[n + s * st] += w / 6 }
        }
        func real(_ w: [[Complex]]) -> [Double] { w.flatMap { $0.flatMap { [2 * $0.re, 2 * $0.im] } } }
        var best: (g: [[Complex]], ratio: Double)? = nil
        let bal = [balance.x, balance.y, balance.z]
        for it in 0..<iterations {
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let G3 = (0..<3).map { j in cj[j].indices.reduce(0.0) { $0 + (cj[j][$1] == 0 ? 0 : cj[j][$1] * U[$1]) } - bal[j] }
            let A = (0..<3).map { real(adjoint(tones, drives: g, weights: cj[$0], gates: G, particle: particle)) }
            var M = [[Double]](repeating: [0, 0, 0], count: 3)
            for a in 0..<3 { for b in 0..<3 { M[a][b] = zip(A[a], A[b]).reduce(0) { $0 + $1.0 * $1.1 } } }
            // Newton on the constraint.
            var step = [Double](repeating: 0, count: A[0].count)
            if let y = solve3(M, G3) {
                for a in 0..<3 { for q in step.indices { step[q] -= A[a][q] * y[a] } }
                let nn = (step.reduce(0) { $0 + $1 * $1 }).squareRoot()
                if nn > 0.1 { step = step.map { $0 * 0.1 / nn } }
            }
            // Rival step, projected onto the null space of A.
            let ws = wells(U, lattice: lat, steps: s)
            let rivals = ws.filter { ($0.position - x).length > wavelength / 4 }
                .map { lat.index($0.ijk.0, $0.ijk.1, $0.ijk.2) }
            let d0 = depth(U, ci)
            if d0 > 0, !rivals.isEmpty {
                var D = rivals.map { depth(U, $0) }
                let mx = D.max()!
                let T = d0 * (0.1 * pow(0.1, Double(it) / Double(iterations)))
                var w = D.map { $0 > mx - 30 * T ? exp(($0 - mx) / T) : 0 }
                let Z = w.reduce(0, +)
                w = w.map { $0 / Z }
                let sm = zip(w, D).reduce(0) { $0 + $1.0 * $1.1 }
                let ratio = sm / d0
                if best == nil || ratio < best!.ratio { best = (g, ratio) }
                var cw = [Double](repeating: 0, count: lat.count)
                for (q, n) in rivals.enumerated() where w[q] > 1e-12 { spread(&cw, n, w[q] * (1 + (D[q] - sm) / T) / d0) }
                spread(&cw, ci, -sm / (d0 * d0))
                var v = real(adjoint(tones, drives: g, weights: cw, gates: G, particle: particle))
                if let y = solve3(M, (0..<3).map { a in zip(A[a], v).reduce(0) { $0 + $1.0 * $1.1 } }) {
                    for a in 0..<3 { for q in v.indices { v[q] -= A[a][q] * y[a] } }
                }
                let vn = (v.reduce(0) { $0 + $1 * $1 }).squareRoot()
                let lr = 0.03 * (1 - 0.9 * Double(it) / Double(iterations))
                if vn > 0 { for q in step.indices { step[q] -= v[q] * lr / vn } }
                D.removeAll()
            }
            var q = 0
            for fi in g.indices { for i in 0..<G { g[fi][i] += Complex(step[q], step[q + 1]); q += 2 } }
            g = normalize(g)
        }
        // Finish on the constraint from the best rival state seen.
        let from = best?.g ?? g
        return moveWell(tones, lattice: lat, gates: G, particle: particle, drives: from, to: x, iterations: 4,
                        balance: balance).drives
    }

    /// Stiffen a trap without moving it: raise its weakest directional curvature at
    /// x (a soft minimum over ∂²U/∂x², ∂²U/∂y², ∂²U/∂z², second differences at
    /// ±`step` read off the lattice) by steps projected onto the null space of the
    /// balance ∇U(x) = balance, then put the balance back. The compiler's other
    /// objectives — one well, placed on its point, holding the weight — say
    /// nothing about stiffness, and a balance can sit on a saddle: a carried bead
    /// was thrown 3 mm from one (`fieldc build`, the tetrahedron's apex column).
    public static func stiffen(_ tones: [Tone], lattice lat: FieldLattice, gates G: Int,
                               particle: ParticleMaterial, drives start: [[Complex]], at x: Vec3,
                               balance: Vec3, step h: Double, iterations: Int = 24) -> [[Complex]] {
        var g = normalize(start)
        let hs = lat.spacing
        let axes = [1, lat.nx, lat.nx * lat.ny]
        let corners = trilinear(lat, x)
        var cj = [[Double]](repeating: [Double](repeating: 0, count: lat.count), count: 3)
        for (j, st) in axes.enumerated() {
            for (n, w) in corners { cj[j][n + st] += w / (2 * hs); cj[j][n - st] -= w / (2 * hs) }
        }
        // Curvature weights along each axis: U(x+h e) − 2U(x) + U(x−h e), over h².
        let dirs = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
        let cw: [[(Int, Double)]] = dirs.map { e in
            var acc: [Int: Double] = [:]
            for (sgn, pt) in [(1.0, x + e * h), (-2.0, x), (1.0, x - e * h)] {
                for (n, w) in trilinear(lat, pt) { acc[n, default: 0] += sgn * w / (h * h) }
            }
            return acc.map { ($0.key, $0.value) }
        }
        func real(_ w: [[Complex]]) -> [Double] { w.flatMap { $0.flatMap { [2 * $0.re, 2 * $0.im] } } }
        let n = 2 * G * tones.count
        let lr0 = 0.05 / Double(n).squareRoot()
        for it in 0..<iterations {
            let U = potential(tones, drives: g, gates: G, particle: particle, count: lat.count)
            let C = cw.map { $0.reduce(0.0) { $0 + U[$1.0] * $1.1 } }
            // Soft minimum of the three curvatures.
            let scale = max(C.map(abs).max() ?? 1, 1e-300)
            let T = 0.1 * scale
            let lo = C.min()!
            let e = C.map { exp(-($0 - lo) / T) }, z = e.reduce(0, +)
            let wsm = e.map { $0 / z }
            let sm = zip(wsm, C).reduce(0) { $0 + $1.0 * $1.1 }
            var weights = [Double](repeating: 0, count: lat.count)
            for (q, list) in cw.enumerated() {
                let dq = wsm[q] * (1 - (C[q] - sm) / T)          // ∂(soft min)/∂C_q
                for (n, w) in list { weights[n] += dq * w }
            }
            var v = real(adjoint(tones, drives: g, weights: weights, gates: G, particle: particle))
            // Keep the balance to first order: project out the constraint's rows.
            let A = (0..<3).map { real(adjoint(tones, drives: g, weights: cj[$0], gates: G, particle: particle)) }
            var M = [[Double]](repeating: [0, 0, 0], count: 3)
            for a in 0..<3 { for b in 0..<3 { M[a][b] = zip(A[a], A[b]).reduce(0) { $0 + $1.0 * $1.1 } } }
            if let y = solve3(M, (0..<3).map { a in zip(A[a], v).reduce(0) { $0 + $1.0 * $1.1 } }) {
                for a in 0..<3 { for q in v.indices { v[q] -= A[a][q] * y[a] } }
            }
            let vn = (v.reduce(0) { $0 + $1 * $1 }).squareRoot()
            guard vn > 0 else { break }
            let lr = lr0 * (1 - 0.8 * Double(it) / Double(iterations))
            var q = 0
            for f in g.indices { for i in 0..<G { g[f][i] += Complex(v[q], v[q + 1]) * (lr / vn); q += 2 } }
            g = normalize(g)
            if it % 6 == 5 {
                g = moveWell(tones, lattice: lat, gates: G, particle: particle, drives: g, to: x, iterations: 3,
                             balance: balance).drives
            }
        }
        return moveWell(tones, lattice: lat, gates: G, particle: particle, drives: g, to: x, iterations: 4,
                        balance: balance).drives
    }

    /// 3×3 linear solve (Cramer); nil if singular.
    static func solve3(_ M: [[Double]], _ b: [Double]) -> [Double]? {
        func det(_ m: [[Double]]) -> Double {
            m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        }
        let d = det(M)
        guard abs(d) > 1e-300 else { return nil }
        return (0..<3).map { c in
            var m = M
            for r in 0..<3 { m[r][c] = b[r] }
            return det(m) / d
        }
    }

    /// Prefer a unique trap at the target; among those, a deeper one.
    static func score(_ r: Result) -> Double {
        guard r.targetDepth > 0, r.siblingRatio.isFinite else { return -.infinity }
        return -r.siblingRatio + 1e-3 * log(r.targetDepth)
    }

    /// Top eigenvector of a small Hermitian matrix (shifted power iteration).
    static func topEigenvector(_ A: [Complex], _ G: Int) -> [Complex] {
        var shift = 0.0
        for q in 0..<(G * G) { shift += A[q].magnitudeSquared }
        shift = shift.squareRoot()
        var v = (0..<G).map { Complex(1 + 0.1 * Double($0), 0.05 * Double($0)) }
        for _ in 0..<300 {
            var w = [Complex](repeating: .zero, count: G)
            for i in 0..<G {
                var s = v[i] * shift
                for j in 0..<G { s += A[i * G + j] * v[j] }
                w[i] = s
            }
            let n = w.reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot()
            guard n > 0 else { break }
            v = w.map { $0 * (1 / n) }
        }
        return v
    }
}
