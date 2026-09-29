import Foundation

/// The unit suite. Run with `fieldc test`.
public enum CoreTests {

    public static func runAll() -> TestHarness {
        let h = TestHarness()
        math(h); geometry(h); propagator(h); gorkov(h); inverse(h)
        pencil(h); trapKinds(h); chordAndVerbs(h); callResponse(h)
        surfaceHologram(h)
        provenance(h); gates(h)
        cad(h); wallsAndPlates(h); air(h); force(h)
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
        h.test("RH-1 FS is the simulated machine") { t in
            let (p, c, w) = RH1Freestanding.standard()
            t.check(p.gateCount == 6, "3 throat piezos x 2 faces, got \(p.gateCount)")
            t.check(c.count == p.elements.count && p.elements.count > 10_000, "virtual apertures with couplings")
            t.near(p.buildVolume.radius, 0.190, 1e-9); t.near(p.buildVolume.height, 0.460, 1e-9)
            t.near(w.capSeparation, 0.460, 1e-9)
            t.near(p.medium.soundSpeed, 343.872, 0.01, "room air 20 C, 50 % RH")
        }
        h.test("desktop RH-1 v0.3 frozen (receipt replay only)") { t in
            // Superseded by the free-standing machine (2026-07-30 canon). Kept
            // so old receipts replay; not maintained.
            t.near(RH1.Dim.buildVolumeDiameter, 280, 0)
            t.near(RH1.Dim.buildVolumeHeight, 300, 0)
            t.near(RH1.Dim.plateDiameter, 300, 0)
            t.near(RH1.Dim.boreDiameter, 80, 0)
            t.check(RH1.Dim.panelCount == 6, "6 phononic panels")
            t.check(RH1.Dim.columnCount == 7, "7 arcade columns")
            // Documented conflict: mech §4 says 40x40; §10 + hardware spec say
            // 40x20 with a CAD-correction note. We build to 40x20.
            t.near(RH1.Dim.columnTangential, 40, 0)
            t.near(RH1.Dim.columnRadial, 20, 0)
        }
        h.test("desktop RH-1 v0.3: 24 acoustic gates (frozen)") { t in
            let p = RH1.preset()
            t.check(p.gateCount == 24, "6 panels x 4 drivers, got \(p.gateCount)")
            t.check(!p.elements.isEmpty, "elements populated")
            t.near(p.buildVolume.radius, 0.140, 1e-9)
            t.near(p.buildVolume.height, 0.300, 1e-9)
        }
        h.test("build volume containment") { t in
            let bv = BuildVolume(radius: 0.14, height: 0.30)
            t.check(bv.contains(Vec3(0, 0, 0.15)), "centre is inside")
            t.check(!bv.contains(Vec3(0.2, 0, 0.15)), "outside radius")
            t.check(!bv.contains(Vec3(0, 0, 0.35)), "above the lid")
        }
        h.test("every element belongs to a valid gate") { t in
            let p = RH1.preset()
            for e in p.elements {
                t.check(e.gateIndex >= 0 && e.gateIndex < p.gateCount,
                        "gate \(e.gateIndex) out of range")
            }
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

    // --------------------------------------------------------------- inverse
    static func inverse(_ h: TestHarness) {
        h.test("phase quantization is applied") { t in
            let con = InverseSolver.Constraints(maxAmplitude: 1, phaseBits: 3)
            let levels = Double(1 << 3)
            for c in con.project([Complex.expi(0.31), Complex.expi(2.0)]) {
                let q = c.phase / (2 * .pi) * levels
                t.near(q, q.rounded(), 1e-9, "phase not on the quantization grid")
            }
        }
        h.test("amplitude ceiling respected") { t in
            let con = InverseSolver.Constraints(maxAmplitude: 0.5)
            for c in con.project([Complex(10, 0), Complex(0, -7)]) {
                t.check(c.magnitude <= 0.5 + 1e-12, "ceiling breached: \(c.magnitude)")
            }
        }
    }

    // ------------------------------------------------------------ matrix pencil
    static func pencil(_ h: TestHarness) {
        // Synthetic ground truth isolates the extractor from the FDTD: build a
        // record from KNOWN damped sinusoids and see whether the pencil returns
        // them. If this passes and the scan still fails, the fault is in the
        // scan data, not the algorithm.
        h.test("matrix pencil recovers known poles") { t in
            let dt = 2e-6
            let N = 600
            let truth: [(f: Double, tau: Double, amp: Double, phase: Double)] = [
                (12_000, 0.0008, 1.0, 0.3),
                (23_500, 0.0005, 0.6, 1.1),
            ]
            var records: [[Double]] = []
            for g in 0..<4 {
                var rec = [Double](repeating: 0, count: N)
                for n in 0..<N {
                    let time = dt * Double(n)
                    for m in truth {
                        rec[n] += m.amp * (1.0 + 0.3 * Double(g))
                              * exp(-time / m.tau)
                              * cos(2 * .pi * m.f * time + m.phase + 0.2 * Double(g))
                    }
                }
                records.append(rec)
            }
            let chords = MatrixPencil.extract(records: records, dt: dt, maxChords: 6)
            t.check(!chords.isEmpty, "no chords extracted")
            // Every true frequency must appear among the recovered poles.
            for m in truth {
                let hit = chords.contains { abs($0.frequencyHz - m.f) < 0.02 * m.f }
                t.check(hit, "did not recover \(m.f) Hz; got "
                    + chords.map { String(format: "%.0f", $0.frequencyHz) }
                            .joined(separator: ", "))
            }
            // And the reconstruction must actually reproduce the record.
            let re = MatrixPencil.synthesize(chords: chords, gates: records.count,
                                             samples: N, dt: dt)
            var worst = 0.0
            for g in records.indices {
                worst = max(worst, re[g].relativeL2(to: records[g]))
            }
            t.check(worst < 0.05,
                    "reconstruction rel L2 = \(String(format: "%.4f", worst)), want < 0.05")
        }
    }

    // ----------------------------------------------------------- trap kinds
    static func trapKinds(_ h: TestHarness) {
        // A focus and a trap are OPPOSITE requests, and confusing them puts
        // matter in the wrong place. This checks the physics, not the code
        // path: at a focus the pressure is high; at a twin trap it is a null
        // sitting in a Gor'kov well.
        h.test("focus makes an antinode, twin trap makes a node") { t in
            let preset = TestPresets.denseOpposedArray(n: 12, separation: 0.10)
            let f = 40_000.0
            let lam = preset.medium.wavelength(at: f)
            let R = preset.buildVolume.radius, sp = lam / 8
            let lat = FieldLattice(
                origin: Vec3(-R, -R, 0.03), spacing: sp,
                nx: Int((2 * R / sp).rounded(.down)) + 1,
                ny: Int((2 * R / sp).rounded(.down)) + 1,
                nz: Int((0.04 / sp).rounded(.down)) + 1)
            let prop = Propagator(elements: preset.elements, lattice: lat,
                                  frequency: f, medium: preset.medium,
                                  gateCount: preset.gateCount)
            let target = Vec3(0, 0, 0.05)
            let cp = [InverseSolver.ControlPoint(position: target, targetAmplitude: 1)]

            let uFocus = InverseSolver.solve(propagator: prop, points: cp,
                                             method: .gspat, iterations: 60,
                                             trap: .focus)
            let uTwin = InverseSolver.solve(propagator: prop, points: cp,
                                            method: .gspat, iterations: 60,
                                            trap: .twinTrap)
            let mean = { (u: [Complex]) -> Double in
                let fld = prop.forward(u)
                return fld.reduce(0.0) { $0 + $1.magnitude } / Double(fld.count)
            }
            let pFocus = prop.pressure(at: target, drive: uFocus).magnitude / mean(uFocus)
            let pTwin = prop.pressure(at: target, drive: uTwin).magnitude / mean(uTwin)
            t.check(pFocus > 3, "focus should be well above the volume mean, got "
                              + String(format: "%.2f", pFocus))
            t.check(pTwin < 0.5, "twin trap should be a NULL at the target, got "
                               + String(format: "%.2f", pTwin))

            // And the twin trap must actually be a Gor'kov minimum there.
            let g = Gorkov(medium: preset.medium, particle: .pla())
            let U = g.potentialField(propagator: prop, drive: uTwin)
            let traps = Gorkov.findTraps(U: U, lattice: lat, limit: 40)
            let nearest = traps.map { ($0.position - target).length }.min() ?? .infinity
            t.check(nearest < lam / 2,
                    "no Gor'kov minimum within lambda/2 of the requested trap; "
                  + "nearest is \(String(format: "%.1f", nearest * 1000)) mm")
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

        h.test("dissolve REVERSES net power flux, not just phase") { t in
            // The claim in Principles §5 is about energy flow, so check energy
            // flow. A sign flip that does not reverse the flux is a relabelled
            // pump, not a drain.
            let preset = TestPresets.denseOpposedArray(n: 8, separation: 0.10)
            let f = 40_000.0
            let lam = preset.medium.wavelength(at: f)
            let R = preset.buildVolume.radius, sp = lam / 4
            let lat = FieldLattice(
                origin: Vec3(-R, -R, 0.02), spacing: sp,
                nx: Int((2 * R / sp).rounded(.down)) + 1,
                ny: Int((2 * R / sp).rounded(.down)) + 1,
                nz: Int((0.06 / sp).rounded(.down)) + 1)
            let prop = Propagator(elements: preset.elements, lattice: lat,
                                  frequency: f, medium: preset.medium,
                                  gateCount: preset.gateCount)
            let target = Vec3(0, 0, 0.05)
            let u = InverseSolver.solve(
                propagator: prop,
                points: [.init(position: target, targetAmplitude: 1)],
                method: .gspat, iterations: 60)
            let add = ChordDrive(frequency: f, gates: u, verb: .assemble)
            let rem = ChordDrive(frequency: f, gates: u, verb: .dissolve)
            let fAdd = ChordField.netFlux(drive: add, preset: preset, lattice: lat,
                                          about: target, halfSize: 1.5 * lam)
            let fRem = ChordField.netFlux(drive: rem, preset: preset, lattice: lat,
                                          about: target, halfSize: 1.5 * lam)
            t.check(fAdd * fRem < 0,
                    "flux must change sign: assemble \(String(format: "%.3e", fAdd)), "
                  + "dissolve \(String(format: "%.3e", fRem))")
            // NOT an equal-magnitude test, and the reason is physics, not
            // tolerance. Conjugating the DRIVE is not time-reversing the
            // PROBLEM: the Green's function still radiates outward, so the
            // conjugate drive produces a converging field rather than the exact
            // time-reverse of the diverging one. A finite boundary can only
            // recapture the fraction of the field it subtends — which is
            // exactly why the papers insist CPA needs conjugate control of BOTH
            // counter-propagating channels, and why one plate cannot absorb
            // what escapes toward the other. Asserting equal magnitude here
            // would be asserting a perfect absorber.
            let recapture = abs(fRem) > 0 ? abs(fAdd) / abs(fRem) : 0
            t.check(recapture > 0.01 && recapture < 100,
                    "recapture ratio implausible: \(String(format: "%.2f", recapture))")
        }
    }

    // ------------------------------------------------------ call & response
    static func callResponse(_ h: TestHarness) {
        func chord(_ f: Double, _ w: Double) -> MatrixPencil.Chord {
            MatrixPencil.Chord(pole: Complex(-50, 2 * .pi * f),
                               portVector: [Complex(w, 0)], weight: w)
        }
        h.test("chord error: absent resonance costs as much as a wrong one") { t in
            let target = [chord(10_000, 1), chord(20_000, 1)]
            let perfect = CallAndResponse.chordError(measured: target, target: target)
            t.near(perfect, 0, 1e-9, "identical lists must score 0")
            let half = CallAndResponse.chordError(measured: [chord(10_000, 1)],
                                                  target: target)
            t.check(half > 0.5, "a workpiece missing half the target's resonances "
                              + "must not score well; got \(half)")
            let none = CallAndResponse.chordError(measured: [], target: target)
            t.check(none >= 1.0, "ringing at nothing must score >= 1, got \(none)")
        }
        h.test("spurious resonances count against") { t in
            let target = [chord(10_000, 1)]
            let extra = [chord(10_000, 1), chord(31_000, 1)]
            t.check(CallAndResponse.chordError(measured: extra, target: target) > 0.5,
                    "an object ringing at frequencies the target never asked for "
                  + "is not a match")
        }
        h.test("the loop stops on rings-true, and on stall") { t in
            let target = [chord(10_000, 1)]
            // Converging: error shrinks each iteration.
            var k = 0
            let good = CallAndResponse(target: target, tolerance: 0.15)
                .run(drive: { _ in ChordDrive(frequency: 40_000, gates: [.one]) },
                     advance: { _ in 0.5 },
                     // Approaches the target weight of 1 from below. An earlier
                     // version decreased PAST it, so the error grew and the loop
                     // correctly reported a stall — the test was wrong, not the
                     // loop.
                     listen: { k += 1
                               return [chord(10_000, 1 - 0.5 * pow(0.5, Double(k)))] })
            t.check(good.rungTrue, "should converge, got: \(good.reason)")
            // Stalled: error never improves.
            let bad = CallAndResponse(target: target, tolerance: 0.01,
                                      maxIterations: 30, stallPatience: 3)
                .run(drive: { _ in ChordDrive(frequency: 40_000, gates: [.one]) },
                     advance: { _ in 0.1 },
                     listen: { [chord(10_000, 0.4)] })
            t.check(!bad.rungTrue && bad.reason.contains("stalled"),
                    "a build that cannot converge must SAY so rather than run to "
                  + "the cap and look finished; got: \(bad.reason)")
            t.check(bad.iterations < 30, "should stop early on stall")
        }
    }

    // -------------------------------------------------------------- surface
    static func surfaceHologram(_ h: TestHarness) {
        // The test that matters: replaying the reference across the recorded
        // surface must reproduce the OBJECT wave. A hologram that does not
        // reconstruct is just a texture.
        h.test("replaying the reference reconstructs the object wave") { t in
            let k = Medium.air.wavenumber(at: 40_000)
            var surf: [SurfaceHologram.SurfacePoint] = []
            let n = 24, pitch = Medium.air.wavelength(at: 40_000) / 2
            for j in 0..<n {
                for i in 0..<n {
                    surf.append(.init(
                        position: Vec3((Double(i) - 11.5) * pitch,
                                       (Double(j) - 11.5) * pitch, 0),
                        normal: Vec3(0, 0, 1), area: pitch * pitch))
                }
            }
            let feed = Vec3(0, 0, -0.05)
            let target = Vec3(0.01, -0.006, 0.07)
            let ref = SurfaceHologram.referenceWave(surface: surf, feed: feed,
                                                    wavenumber: k)
            let obj = SurfaceHologram.objectWave(surface: surf, targets: [target],
                                                 wavenumber: k)
            let holo = SurfaceHologram.record(surface: surf, reference: ref,
                                              object: obj)
            let emitted = SurfaceHologram.reconstruct(holo, reference: ref)

            // Propagate the emitted aperture field to a plane and check the
            // peak lands on the target rather than anywhere else.
            func amplitude(at x: Vec3) -> Double {
                var acc = Complex.zero
                for (i, p) in surf.enumerated() {
                    let r = max((x - p.position).length, 1e-9)
                    acc += emitted[i] * Complex.expi(k * r) / r * p.area
                }
                return acc.magnitude
            }
            let atTarget = amplitude(at: target)
            var best = 0.0, bestPos = Vec3.zero
            var scan = 0.0
            var count = 0
            for a in -10...10 {
                for b in -10...10 {
                    let x = Vec3(Double(a) * 0.004, Double(b) * 0.004, target.z)
                    let v = amplitude(at: x)
                    scan += v; count += 1
                    if v > best { best = v; bestPos = x }
                }
            }
            let mean = scan / Double(count)
            t.check(atTarget > 3 * mean,
                    "reconstruction must concentrate at the target: "
                  + "\(String(format: "%.2f", atTarget / mean))x the plane mean")
            t.check((bestPos - target).length < 0.008,
                    "peak landed \(String(format: "%.1f", (bestPos - target).length * 1000))"
                  + " mm from the target")
            t.check(holo.saturatedFraction < 0.5,
                    "hologram is clipping: \(String(format: "%.0f%%", holo.saturatedFraction * 100))"
                  + " of the aperture at the rails")
        }
    }

    // ------------------------------------------------------------ provenance
    /// G17 enforcement. This rule has been asserted repeatedly as the app's
    /// central honesty commitment and was, until now, entirely untested — which
    /// is exactly the kind of gap an audit is for.
    static func provenance(_ h: TestHarness) {
        func patternJSON(chordBody: String, measured: Int, inferred: Int) -> Data {
            Data(("""
            {"version":"pattern/0.2",
             "meta":{"name":"t","date":"now","source":"emulated-scan",
                     "machine":"m","calibrationRef":"c",
                     "reconstruction":{"rung":"L0","greensFunction":"modelled"},
                     "counts":{"measured":\(measured),"inferred":\(inferred)}},
             "material":{"name":"PLA","density":1240,"soundSpeed":2220},
             "band":[20000,80000],
             "chords":[\(chordBody)]}
            """).utf8)
        }

        h.test("a chord without provenance is REJECTED, not defaulted") { t in
            let data = patternJSON(
                chordBody: #"{"p":[-1,1000],"r":[[1,0]],"weight":1}"#,
                measured: 1, inferred: 0)
            do {
                _ = try PatternFile.decode(data)
                t.fail("decoded a chord with no provenance — it must be rejected, "
                     + "because assuming 'measured' IS the failure mode")
            } catch { /* expected */ }
        }

        h.test("an inferred chord without inferredBy is REJECTED") { t in
            let data = patternJSON(
                chordBody: #"{"p":[-1,1000],"r":[[1,0]],"weight":1,"provenance":"inferred"}"#,
                measured: 0, inferred: 1)
            do {
                _ = try PatternFile.decode(data)
                t.fail("accepted an inferred chord with no source — a fabricated "
                     + "interior must always be traceable")
            } catch { /* expected */ }
        }

        h.test("an unknown provenance value is REJECTED") { t in
            let data = patternJSON(
                chordBody: #"{"p":[-1,1000],"r":[[1,0]],"weight":1,"provenance":"probably"}"#,
                measured: 1, inferred: 0)
            do {
                _ = try PatternFile.decode(data)
                t.fail("accepted provenance 'probably'")
            } catch { /* expected */ }
        }

        h.test("declared counts must match the chord list") { t in
            let data = patternJSON(
                chordBody: #"{"p":[-1,1000],"r":[[1,0]],"weight":1,"provenance":"measured"}"#,
                measured: 7, inferred: 0)
            do {
                _ = try PatternFile.decode(data)
                t.fail("accepted meta.counts that disagrees with the chord list")
            } catch { /* expected */ }
        }

        h.test("a well-formed pattern decodes and excludes inferred from build") { t in
            let body = #"{"p":[-1,1000],"r":[[1,0]],"weight":1,"provenance":"measured"},"#
                     + #"{"p":[-2,2000],"r":[[1,0]],"weight":1,"provenance":"inferred","inferredBy":"prior/1"}"#
            do {
                let pat = try PatternFile.decode(
                    patternJSON(chordBody: body, measured: 1, inferred: 1))
                t.check(pat.chords.count == 2, "both chords present")
                t.check(pat.buildableChords.count == 1,
                        "inferred content must be excluded from what a build "
                      + "may fabricate to; got \(pat.buildableChords.count)")
            } catch { t.fail("rejected a well-formed pattern: \(error)") }
        }
    }

    // ----------------------------------------------------------------- gates
    static func gates(_ h: TestHarness) {
        h.test("all physics gates pass") { t in
            for g in PhysicsGates.runAll() where g.comparison != .informational {
                t.check(g.passed, g.line)
            }
        }
        h.test("reciprocity detects asymmetry") { t in
            var S = [[Complex]](repeating: [Complex](repeating: .zero, count: 3), count: 3)
            for i in 0..<3 { for j in 0..<3 { S[i][j] = Complex(Double(i + j), 0) } }
            t.check(PhysicsGates.g15Reciprocity(S).passed, "symmetric matrix should pass")
            S[0][2] = Complex(99, 0)
            t.check(!PhysicsGates.g15Reciprocity(S).passed, "asymmetry must be caught")
        }
        h.test("receipt round-trips through JSON") { t in
            do {
                let r = Receipt(name: "t", gates: PhysicsGates.runAll(), durationSeconds: 1)
                let data = try r.json()
                let back = try JSONDecoder().decode(Receipt.self, from: data)
                t.check(back.gates.count == r.gates.count, "gate count preserved")
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
            t.near(ThermalDrift.relativeSpeedDrift(room) * 100, 0.182, 0.002, "dc/c per K, %")
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
    }
}
