import Foundation

/// The unit suite. Run with `fieldc test`.
public enum CoreTests {

    /// One test group by name (`fieldc test scatter`) — fast iteration on one area.
    public static func run(group: String) -> TestHarness? {
        let groups: [String: (TestHarness) -> Void] = [
            "math": math, "geometry": geometry, "propagator": propagator, "gorkov": gorkov,
            "cad": cad, "plates": wallsAndPlates, "air": air,
            "force": force, "scatter": scatter, "array": plateArray, "em": em, "machine": machine, "flow": flow]
        guard let g = groups[group] else { return nil }
        let h = TestHarness()
        g(h)
        return h
    }

    public static func runAll() -> TestHarness {
        let h = TestHarness()
        math(h); geometry(h); propagator(h); gorkov(h)
        chordAndVerbs(h); gates(h)
        cad(h); wallsAndPlates(h); air(h); force(h); scatter(h); plateArray(h); em(h); machine(h); flow(h)
        return h
    }

    // ------------------------------------------------------------------ math
    static func math(_ h: TestHarness) {
        h.test("complex arithmetic") { t in
            let a = Complex(3, 4), b = Complex(1, -2)
            t.near(a.magnitude, 5, 1e-12, "magnitude")
            t.near((a * b).re, 11, 1e-12, "product re")
            t.near((a * b).im, -2, 1e-12, "product im")
            let q = a / b
            t.near((q * b).re, a.re, 1e-10, "division roundtrip re")
            t.near((q * b).im, a.im, 1e-10, "division roundtrip im")
        }
        h.test("expi is unit modulus") { t in
            for i in 0..<32 { t.near(Complex.expi(Double(i) * 0.37).magnitude, 1, 1e-12) }
        }
        h.test("bessel J1 zeros and value") { t in
            for z in [3.8317059702, 7.0155866698, 10.1734681351] {
                t.near(besselJ1(z), 0, 2e-6, "J1 zero at \(z)")
            }
            t.near(besselJ1(1.0), 0.4400505857, 1e-6, "J1(1)")
        }
        h.test("bessel J0 zeros and value") { t in
            for z in [2.404825557695773, 5.520078110286311, 8.653727912911013] {
                t.near(besselJ0(z), 0, 2e-7, "J0 zero at \(z)")
            }
            t.near(besselJ0(1.0), 0.7651976866, 1e-7, "J0(1)")
            t.near(besselJ0(10.0), -0.2459357645, 1e-7, "J0(10)")
        }
    }

    // -------------------------------------------------------------- geometry
    static func geometry(_ h: TestHarness) {
        h.test("icosphere volume near closed form") { t in
            let r = 0.05
            let exact = 4.0 / 3.0 * Double.pi * r * r * r
            t.near(Mesh.sphere(radius: r, subdivisions: 4).signedVolume / exact, 1.0, 0.01)
        }
        h.test("cube volume exact") { t in
            let s = 0.05
            t.near(Mesh.cube(side: s).signedVolume, s * s * s, 1e-12)
        }
        h.test("RH-1 canonical geometry (RH1Design)") { t in
            // Load-bearing: the numbers the CAD, the viewport chrome and the
            // physics all read. A silent edit desynchronises all three.
            let d = RH1Design()
            t.near(d.plateDiameter, 410, 0); t.near(d.boreDiameter, 12, 0)
            t.near(d.chamberFloor, 1060, 0); t.near(d.chamberCeiling, 1520, 0)
            t.near(d.buildChamberHeight, 460, 0)
            t.near(d.bodyDiameter, 460, 0); t.near(d.overallHeight, 1650, 0)
            t.near(d.rearGlassOD, 444, 0); t.near(d.frontGlassOD, 464, 0)
            t.check(d.slotArms == 12, "12 spiral slots"); t.check(d.columnCount == 7, "7 columns")
        }
        h.test("build volume containment") { t in
            let bv = BuildVolume(radius: 0.14, height: 0.30)
            t.check(bv.contains(Vec3(0, 0, 0.15)), "centre is inside")
            t.check(!bv.contains(Vec3(0.2, 0, 0.15)), "outside radius")
            t.check(!bv.contains(Vec3(0, 0, 0.35)), "above the lid")
        }
    }

    // ------------------------------------------------------------ propagator
    static func propagator(_ h: TestHarness) {
        h.test("point evaluator matches cached operator") { t in
            // Two different code paths computing the same thing; they must agree.
            let preset = TestPresets.singlePlate(n: 6)
            let lat = FieldLattice(origin: Vec3(-0.01, -0.01, 0.03), spacing: 0.005,
                                   nx: 3, ny: 3, nz: 3)
            let prop = Propagator(elements: preset.elements, lattice: lat,
                                  frequency: 40_000, medium: preset.medium,
                                  gateCount: preset.gateCount)
            var drive = [Complex](repeating: .zero, count: prop.gateCount)
            for i in drive.indices { drive[i] = Complex.expi(Double(i) * 0.7) }
            let viaOp = prop.forward(drive)
            for n in 0..<lat.count {
                let direct = prop.pressure(at: lat.position(linear: n), drive: drive)
                t.near(viaOp[n].re, direct.re, abs(direct.re) * 1e-9 + 1e-12, "re[\(n)]")
                t.near(viaOp[n].im, direct.im, abs(direct.im) * 1e-9 + 1e-12, "im[\(n)]")
            }
        }
        h.test("adjoint is the conjugate transpose") { t in
            // <Hu, y> == <u, H^H y>. If this fails the inverse solver is wrong.
            let preset = TestPresets.singlePlate(n: 4)
            let lat = FieldLattice(origin: Vec3(-0.01, -0.01, 0.03), spacing: 0.006,
                                   nx: 2, ny: 2, nz: 2)
            let prop = Propagator(elements: preset.elements, lattice: lat,
                                  frequency: 40_000, medium: preset.medium,
                                  gateCount: preset.gateCount)
            var u = [Complex](repeating: .zero, count: prop.gateCount)
            for i in u.indices { u[i] = Complex(cos(Double(i)), sin(Double(i) * 1.3)) }
            var y = [Complex](repeating: .zero, count: lat.count)
            for i in y.indices { y[i] = Complex(sin(Double(i) * 0.9), cos(Double(i) * 0.4)) }
            let Hu = prop.forward(u)
            var lhs = Complex.zero
            for i in Hu.indices { lhs += Hu[i] * y[i].conjugate }
            let HHy = prop.adjoint(y)
            var rhs = Complex.zero
            for i in u.indices { rhs += u[i] * HHy[i].conjugate }
            t.near(lhs.re, rhs.re, abs(lhs.re) * 1e-9 + 1e-15, "adjoint re")
            t.near(lhs.im, rhs.im, abs(lhs.im) * 1e-9 + 1e-15, "adjoint im")
        }
    }

    // ---------------------------------------------------------------- gorkov
    static func gorkov(_ h: TestHarness) {
        h.test("contrast is positive for solid in air") { t in
            t.check(Gorkov(medium: .air, particle: .pla()).contrast > 0,
                    "solid in air must trap at pressure NODES")
        }
        h.test("Settnes-Bruus normalization agrees") { t in
            let g = Gorkov(medium: .air, particle: .pla())
            for i in 1..<20 {
                let z = Double(i) * 0.0004
                let a = g.analyticStandingWaveForce(P0: 1000, z: z, frequency: 40_000)
                let b = g.analyticSettnesBruus(P0: 1000, z: z, frequency: 40_000)
                t.near(a, b, abs(a) * 1e-12 + 1e-30, "z=\(z)")
            }
        }
        h.test("force pushes toward the pressure node") { t in
            // The sign trap that G7 caught. p = P0 sin(kz) has its node at z=0,
            // so just above it the force must be negative.
            let g = Gorkov(medium: .air, particle: .pla())
            let lambda = Medium.air.wavelength(at: 40_000)
            let f = g.analyticStandingWaveForce(P0: 1000, z: lambda / 8, frequency: 40_000)
            t.check(f < 0, "positive-contrast particle must be pulled to the node, got \(f)")
        }
    }

    // ------------------------------------------------------- chord & verbs
    static func chordAndVerbs(_ h: TestHarness) {
        h.test("a chord is more than one tone, and shares power") { t in
            let g = [Complex(1, 0), Complex(0, 1)]
            let one = ChordDrive(frequency: 40_000, gates: g)
            let three = ChordDrive(tones: [
                .init(frequency: 30_000, gates: g),
                .init(frequency: 40_000, gates: g),
                .init(frequency: 50_000, gates: g)])
            t.check(one.tones.count == 1 && three.tones.count == 3, "tone counts")
            t.near(three.powerNormalised(to: 1).power, 1, 1e-9,
                   "a 3-tone chord must SHARE power, not draw 3x")
        }

        h.test("dissolve is assemble conjugated — the one sign flip") { t in
            let g = [Complex(0.6, 0.8), Complex(-0.3, 0.4)]
            let a = ChordDrive(frequency: 40_000, gates: g, verb: .assemble).applied()
            let d = ChordDrive(frequency: 40_000, gates: g, verb: .dissolve).applied()
            for i in g.indices {
                t.near(a.tones[0].gates[i].re, d.tones[0].gates[i].re, 1e-12, "re")
                t.near(a.tones[0].gates[i].im, -d.tones[0].gates[i].im, 1e-12,
                       "im must invert")
                t.near(a.tones[0].gates[i].magnitude,
                       d.tones[0].gates[i].magnitude, 1e-12,
                       "amplitude must NOT change — only phase")
            }
        }
    }

    // ----------------------------------------------------------------- gates
    static func gates(_ h: TestHarness) {
        h.test("all physics gates pass") { t in
            for g in PhysicsGates.runAll() where g.comparison != .informational {
                t.check(g.passed, g.line)
            }
        }
        h.test("receipt round-trips through JSON, ∞ and NaN included") { t in
            do {
                var gates = PhysicsGates.runAll()
                gates.append(GateResult(id: "X", name: "no well", measured: .infinity, threshold: 0,
                                        comparison: .informational, detail: ""))
                gates.append(GateResult(id: "Y", name: "lost", measured: .nan, threshold: 0,
                                        comparison: .informational, detail: ""))
                let r = Receipt(name: "t", gates: gates, durationSeconds: 1)
                let back = try Receipt.decode(try r.json())
                t.check(back.gates.count == r.gates.count, "gate count preserved")
                t.check(back.gates[back.gates.count - 2].measured == .infinity && back.gates.last!.measured.isNaN,
                        "∞ and NaN survive")
            } catch { t.fail("\(error)") }
        }
    }

    // ------------------------------------------------------------------- air
    static func air(_ h: TestHarness) {
        h.test("humid air: sound speed, density, ISO 9613-1 absorption") { t in
            let dry = AirState(temperatureC: 20, humidity: 0)
            t.near(dry.soundSpeed, 343.235, 0.01, "dry air 20 C")
            t.near(dry.density, 1.2041, 1e-3, "dry air density")
            let room = Medium.air(temperatureC: 20, humidity: 50)
            t.near(room.soundSpeed, 343.872, 0.01, "20 C, 50 % RH")
            let s = room.air!
            t.near(s.absorptionDB(at: 1_000) * 1000, 4.66, 0.05, "1 kHz, dB/km (ISO table 4.66)")
            t.near(s.absorptionDB(at: 40_000), 1.32, 0.02, "40 kHz, dB/m")
            t.near(s.absorptionDB(at: 200_000), 8.23, 0.05, "200 kHz, dB/m")
            t.near(Medium.air.absorption(at: 40_000), 0, 0, "legacy fixed medium: no absorption")
            t.near(room.shifted(byKelvin: 1).air!.temperatureC, 21, 1e-12)
        }
        h.test("propagator: absorption is exp(-alpha r) on every path") { t in
            let el = Element(position: .zero, normal: Vec3(0, 0, 1), area: 1e-6, surface: .lowerCap,
                             gateIndex: 0, directivity: .monopole)
            let r = 0.3
            let lat = FieldLattice(origin: Vec3(0, 0, r), spacing: 1, nx: 1, ny: 1, nz: 1)
            let wet = Medium.air(temperatureC: 20, humidity: 50)
            var still = wet; still.air = nil
            let f = 100_000.0
            let a = Propagator(elements: [el], lattice: lat, frequency: f, medium: wet).H[0].magnitude
            let b = Propagator(elements: [el], lattice: lat, frequency: f, medium: still).H[0].magnitude
            t.near(a / b, exp(-wet.absorption(at: f) * r), 1e-12, "cached operator")
            let row = Propagator(elements: [el], lattice: lat, frequency: f, medium: wet).gateRow(at: Vec3(0, 0, r))
            t.near(row[0].magnitude, a, 1e-12 * a, "point evaluator agrees")
        }
    }

    // ----------------------------------------------------------------- force
    static func force(_ h: TestHarness) {
        let preset = TestPresets.singlePlate(n: 6)
        let wet = Medium.air(temperatureC: 20, humidity: 50)
        let walls = Propagator.Walls(capSeparation: 0.2, order: 2, reflectionCoefficient: 0.8)
        let lat = FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1)
        let prop = Propagator(elements: preset.elements, lattice: lat, frequency: 40_000,
                              medium: wet, gateCount: preset.gateCount, walls: walls)
        let x = Vec3(0.004, -0.003, 0.061)
        h.test("gate gradient rows match finite differences (walls, absorption)") { t in
            let rows = prop.gateGradientRows(at: x)
            let hstep = 1e-6
            for (axis, e) in [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)].enumerated() {
                let up = prop.gateRow(at: x + e * hstep), dn = prop.gateRow(at: x - e * hstep)
                let fd = zip(up, dn).map { ($0 - $1) * (1 / (2 * hstep)) }
                t.check(rows.grad[axis].relativeL2(to: fd) < 1e-5, "axis \(axis)")
            }
            t.check(rows.p.relativeL2(to: prop.gateRow(at: x)) < 1e-12, "p rows = gateRow")
        }
        h.test("force compiler's quadratic form equals the Gor'kov potential") { t in
            let particle = ParticleMaterial.pla()
            var rng = SplitMix64(seed: 3)
            let g = (0..<preset.gateCount).map { _ in Complex(rng.nextUnit() - 0.5, rng.nextUnit() - 0.5) }
            let rows = prop.gateGradientRows(at: x)
            var flat: [Complex] = []
            for gi in 0..<preset.gateCount {
                flat.append(rows.p[gi]); for c in 0..<3 { flat.append(rows.grad[c][gi]) }
            }
            let tone = ForceCompiler.Tone(frequency: 40_000, medium: wet, rows: flat)
            let U = ForceCompiler.potential([tone], drives: [g], gates: preset.gateCount,
                                            particle: particle, count: 1)[0]
            let ref = Gorkov(medium: wet, particle: particle)
                .potential(p: prop.pressure(at: x, drive: g), v: prop.velocity(at: x, drive: g))
            t.near(U / ref, 1, 1e-9, "gHKg vs Gorkov.potential")
        }
        h.test("force compiler's adjoint = the derivative of Σ c(x) U(x), two tones") { t in
            // Random rows on 40 points, two tones, random weights c: the
            // Wirtinger gradient must match central differences of the real
            // functional in every drive's real and imaginary part.
            let particle = ParticleMaterial.pla()
            var rng = SplitMix64(seed: 7)
            func rnd() -> Complex { Complex(rng.nextUnit() - 0.5, rng.nextUnit() - 0.5) }
            let G = 3, N = 40
            let tones = [40_000.0, 55_000.0].map { f in
                ForceCompiler.Tone(frequency: f, medium: wet, rows: (0..<(N * G * 4)).map { _ in rnd() * 1e3 })
            }
            let c = (0..<N).map { _ in rng.nextUnit() - 0.3 }
            let g = tones.map { _ in (0..<G).map { _ in rnd() } }
            func F(_ g: [[Complex]]) -> Double {
                let U = ForceCompiler.potential(tones, drives: g, gates: G, particle: particle, count: N)
                return zip(c, U).reduce(0) { $0 + $1.0 * $1.1 }
            }
            let grad = ForceCompiler.adjoint(tones, drives: g, weights: c, gates: G, particle: particle)
            var worst = 0.0
            let h = 1e-6
            for f in 0..<2 {
                for i in 0..<G {
                    for (part, e) in [(0, Complex(h, 0)), (1, Complex(0, h))] {
                        var gp = g, gm = g
                        gp[f][i] += e; gm[f][i] -= e
                        let fd = (F(gp) - F(gm)) / (2 * h)
                        let an = 2 * (part == 0 ? grad[f][i].re : grad[f][i].im)
                        let err = abs(fd - an) / max(abs(fd), 1e-300)
                        if !(err <= worst) { worst = err }
                    }
                }
            }
            t.check(worst < 1e-6, "worst relative error \(worst)")
        }
    }

    // ----------------------------------------------------------- plate array
    static func plateArray(_ h: TestHarness) {
        h.test("plate array: Vogel spiral fills the disc, every element at its own radius") { t in
            let n = 384, R = 0.205
            let pts = PlateArray.vogel(n, radius: R)
            let radii = pts.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }
            t.check(radii.allSatisfy { $0 <= R + 1e-12 }, "inside the disc")
            t.check(Set(radii.map { Int(($0 * 1e7).rounded()) }).count == n, "unique radii")
            var dMin = Double.infinity
            for i in 0..<n { for j in (i + 1)..<n {
                dMin = min(dMin, ((pts[i].x - pts[j].x) * (pts[i].x - pts[j].x) + (pts[i].y - pts[j].y) * (pts[i].y - pts[j].y)).squareRoot())
            } }
            let pitch = (Double.pi * R * R / Double(n)).squareRoot()
            t.check(dMin > 0.5 * pitch, String(format: "nearest neighbours %.1f mm apart (pitch %.1f mm)", dMin * 1000, pitch * 1000))
            let arr = PlateArray(perPlate: 12)
            let els = arr.elements()
            t.check(els.count == 24 && els.prefix(12).allSatisfy { $0.position.z == 0 && $0.normal.z == 1 }
                    && els.suffix(12).allSatisfy { $0.position.z == arr.gap && $0.normal.z == -1 }, "lower plate up, upper plate down")
            t.check(els.enumerated().allSatisfy { $0.offset == $0.element.gateIndex }, "one channel per element")
        }
        h.test("G-A2: a piston element radiates as the Rayleigh integral over its face says") { t in
            // One Ø5 mm piston, free field, 70 kHz (ka = 3.2): the element model
            // (far-field 2J1(x)/x directivity) against the Rayleigh integral
            // i ρck/(2π) ∫ e^{ikR}/R dS summed over the face, at 230 mm and 0–42°
            // off axis — the angles at which the plates see the work volume.
            let air = Medium.air(temperatureC: 20, humidity: 50)
            let f = 70_000.0, a = 2.5e-3
            let k = air.wavenumber(at: f)
            let el = Element(position: Vec3(0, 0, 0), normal: Vec3(0, 0, 1), area: Double.pi * a * a,
                             surface: .lowerCap, gateIndex: 0)
            let ref = Propagator(elements: [el], lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                 frequency: f, medium: Medium(density: air.density, soundSpeed: air.soundSpeed), gateCount: 1)
            let pre = air.density * air.soundSpeed * k / (2 * Double.pi)
            var worst = 0.0
            for deg in [0.0, 15, 30, 42] {
                let th = deg * Double.pi / 180, r = 0.23
                let x = Vec3(r * sin(th), 0, r * cos(th))
                let model = ref.gateGradientRows(at: x).p[0]
                var integral = Complex.zero
                let nr = 60, nt = 120
                for i in 0..<nr {
                    let rr = a * (Double(i) + 0.5) / Double(nr), dr = a / Double(nr)
                    for j in 0..<nt {
                        let ph = 2 * Double.pi * (Double(j) + 0.5) / Double(nt)
                        let s = Vec3(rr * cos(ph), rr * sin(ph), 0)
                        let R = (x - s).length
                        integral += Complex(0, pre) * Complex.expi(k * R) * (rr * dr * 2 * Double.pi / Double(nt) / R)
                    }
                }
                worst = max(worst, (model - integral).magnitude / integral.magnitude)
            }
            t.check(worst < 0.01, String(format: "worst relative difference %.2e over 0–42° at 230 mm", worst))
        }
    }

    // --------------------------------------------------------------- scatter
    static func scatter(_ h: TestHarness) {
        h.test("G-S1: a small rigid sphere scatters as the exact series says (ka = 0.1)") { t in
            // Plane wave e^{ikz} on a rigid, immovable sphere: the exact field is
            // p_sc = −Σ (2n+1) iⁿ [j_n'(ka)/h_n'(ka)] h_n(kr) P_n(cos θ). The
            // monopole + dipole model must agree to O((ka)²).
            let a = 1e-4, k = 1000.0
            func sj(_ n: Int, _ x: Double) -> Double {                 // j_n by its series
                var term = 1.0
                for m in 0..<n { term *= x / Double(2 * m + 3) }
                term /= 1                                                // x^n/(2n+1)!!
                var s = 0.0, t2 = term
                for q in 0..<40 {
                    s += t2
                    t2 *= -x * x / (2 * Double(q + 1) * Double(2 * n + 2 * q + 3))
                }
                return s
            }
            func sy(_ n: Int, _ x: Double) -> Double {                 // y_n by upward recurrence
                var y0 = -cos(x) / x, y1 = -cos(x) / (x * x) - sin(x) / x
                if n == 0 { return y0 }
                for m in 1..<max(1, n) { let y2 = Double(2 * m + 1) / x * y1 - y0; y0 = y1; y1 = y2 }
                return y1
            }
            func sh(_ n: Int, _ x: Double) -> Complex { Complex(sj(n, x), sy(n, x)) }
            func dj(_ n: Int, _ x: Double) -> Double { n == 0 ? -sj(1, x) : sj(n - 1, x) - Double(n + 1) / x * sj(n, x) }
            func dh(_ n: Int, _ x: Double) -> Complex {
                n == 0 ? sh(1, x) * -1.0 : sh(n - 1, x) - sh(n, x) * (Double(n + 1) / x)
            }
            func legendre(_ n: Int, _ c: Double) -> Double {
                var p0 = 1.0, p1 = c
                if n == 0 { return p0 }
                for m in 1..<max(1, n) { let p2 = (Double(2 * m + 1) * c * p1 - Double(m) * p0) / Double(m + 1); p0 = p1; p1 = p2 }
                return p1
            }
            func iPow(_ n: Int) -> Complex { [Complex(1, 0), Complex(0, 1), Complex(-1, 0), Complex(0, -1)][n % 4] }
            let sc = Scatterers(centers: [Vec3(0, 0, 0)], radius: a, f1: 1, f2: 1)
            let src = sc.solve(incident: [(p: [Complex.one], grad: [[.zero], [.zero], [Complex(0, k)]])], k: Complex(k, 0))
            var worst = 0.0
            for r in [3 * a, 10 * a] {
                var errs: [Double] = [], mags: [Double] = []
                for deg in [0.0, 60, 120, 180] {
                    let th = deg * .pi / 180
                    var exact = Complex.zero
                    for n in 0...6 {
                        let coef = Complex(dj(n, k * a), 0) / dh(n, k * a)
                        exact -= iPow(n) * coef * sh(n, k * r) * (Double(2 * n + 1) * legendre(n, cos(th)))
                    }
                    let model = sc.field(at: Vec3(r * sin(th), 0, r * cos(th)), sources: src).p[0]
                    errs.append((model - exact).magnitude); mags.append(exact.magnitude)
                }
                let e = errs.max()! / mags.max()!
                if !(e <= worst) { worst = e }
            }
            t.check(worst < 0.02, "worst relative difference at r = 3a and 10a: \(worst)")
        }
        h.test("G-S2: two beads in an oscillating flow — attract side by side, repel end to end (Koenig)") { t in
            // A standing wave's velocity antinode, ∇p = k ẑ at the origin, p = 0.
            // Bead 1 there; bead 2 at R, angle θ from the flow. The interaction
            // energy of two small rigid spheres in the near field (kR ≪ 1) is
            // U = −(π/2) f2² ρ0 a⁶ |v0|² (1 − 3cos²θ)/R³.
            let air = Medium(density: 1.2, soundSpeed: 343)
            let a = 1e-4, k = 100.0, omega = k * air.soundSpeed
            let bead = ParticleMaterial(density: 1e9, soundSpeed: 1e6, radius: a)   // rigid, immovable
            let (K1, K2) = ForceCompiler.coefficients(particle: bead, medium: air, frequency: omega / (2 * .pi))
            let f2 = 2 * (bead.density - air.density) / (2 * bead.density + air.density)
            let sc = Scatterers(centers: [Vec3(0, 0, 0)], radius: a, f1: 1, f2: 1)
            let src = sc.solve(incident: [(p: [Complex.zero], grad: [[.zero], [.zero], [Complex(k, 0)]])], k: Complex(k, 0))
            let v0 = k / (omega * air.density)
            var worst = 0.0
            for R in [4 * a, 6 * a] {
                for deg in [0.0, 30, 90] {
                    let th = deg * .pi / 180
                    let x = Vec3(R * sin(th), 0, R * cos(th))
                    let pin = Complex(sin(k * x.z), 0)
                    let gin = [Complex.zero, .zero, Complex(k * cos(k * x.z), 0)]
                    let f = sc.field(at: x, sources: src)
                    let p = pin + f.p[0]
                    let gtot = (0..<3).map { gin[$0] + f.grad[$0][0] }
                    let U = K1 * p.magnitudeSquared - K2 * gtot.reduce(0) { $0 + $1.magnitudeSquared }
                    let U0 = K1 * pin.magnitudeSquared - K2 * gin.reduce(0) { $0 + $1.magnitudeSquared }
                    let expect = -Double.pi / 2 * f2 * 1 * air.density * pow(a, 6) * v0 * v0
                        * (1 - 3 * cos(th) * cos(th)) / (R * R * R)
                    let err = abs((U - U0) - expect) / abs(expect)
                    if !(err <= worst) { worst = err }
                }
            }
            t.check(worst < 0.03, "worst relative difference from the Koenig energy: \(worst)")
        }
    }
}
