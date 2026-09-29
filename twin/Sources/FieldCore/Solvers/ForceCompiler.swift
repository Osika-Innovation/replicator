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
        /// Adam iterations of the all-points refinement (`smooth`); 0 = off.
        public var smoothIterations = 240
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
                    DispatchQueue.concurrentPerform(iterations: count) { n in
                        var s = [Complex](repeating: .zero, count: 4)
                        let base = n * G * 4
                        for gi in 0..<G {
                            let d = g[gi]
                            for c in 0..<4 { s[c] += r[base + gi * 4 + c] * d }
                        }
                        u[n] += k1 * s[0].magnitudeSquared
                            - k2 * (s[1].magnitudeSquared + s[2].magnitudeSquared + s[3].magnitudeSquared)
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
        var out: [Well] = []
        guard lat.nx > 2 * s + 1, lat.ny > 2 * s + 1, lat.nz > 2 * s + 1 else { return out }
        for k in s..<(lat.nz - s) {
            for j in s..<(lat.ny - s) {
                for i in s..<(lat.nx - s) {
                    let u = U[lat.index(i, j, k)]
                    let nb = [U[lat.index(i-1, j, k)], U[lat.index(i+1, j, k)], U[lat.index(i, j-1, k)],
                              U[lat.index(i, j+1, k)], U[lat.index(i, j, k-1)], U[lat.index(i, j, k+1)]]
                    guard nb.allSatisfy({ $0 > u }) else { continue }
                    let shell = [U[lat.index(i-s, j, k)], U[lat.index(i+s, j, k)], U[lat.index(i, j-s, k)],
                                 U[lat.index(i, j+s, k)], U[lat.index(i, j, k-s)], U[lat.index(i, j, k+s)]]
                    let d = shell.reduce(0, +) / 6 - u
                    if d > 0 { out.append(Well(ijk: (i, j, k), position: lat.position(i, j, k), depth: d)) }
                }
            }
        }
        return out.sorted { $0.depth > $1.depth }
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
                               starts: [[[Complex]]] = []) -> Result {
        let c = ((lat.nx - 1) / 2, (lat.ny - 1) / 2, (lat.nz - 1) / 2)
        let target = lat.position(c.0, c.1, c.2)
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
            if best == nil || score(r) > score(best!) { best = r }
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
            if tones.count > 1 {
                let each = tones.map { t in
                    compile([t], lattice: lat, gates: G, particle: particle, wavelength: wavelength, options: o)
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
                    if score(rs) > score(best!) { best = rs }
                }
            }
            for start in starts2 {
                let r = smooth(tones, lattice: lat, gates: G, particle: particle, wavelength: wavelength,
                               options: o, target: target, center: c, start: start,
                               iterations: o.smoothIterations)
                if score(r) > score(best!) { best = r }
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
            let tw = ws.filter { ($0.position - target).length <= wavelength / 4 }
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
            let grad = adjoint(tones, drives: g, weights: cw, gates: G, particle: particle)
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
                if score(r) > score(best) { best = r }
            }
        }
        return best
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
