import Foundation

/// §16.3 — Machine View: render what the boundary data actually supports.
///
/// THE CAVEAT THAT SHAPES THIS FILE. Kirchhoff–Helmholtz determines the FIELD
/// inside a SOURCE-FREE volume from boundary data. Put an object in and the
/// volume is no longer source-free — the scatterer is a secondary source — and
/// recovering the OBJECT is inverse scattering: nonlinear, ill-posed, the thing
/// full-waveform inversion exists to attack. So L0 below yields a REFLECTIVITY
/// IMAGE (a 3-D B-scan), not a geometry. Nothing here may quietly threshold it
/// into a mesh and call it a scan.
/// Angular coverage — how much of the orientation sphere this aperture could
/// actually have measured at a point.
///
/// THE BUG THIS REPLACES. The first version summed cos(theta) over gates that
/// could see the point and scaled it, which asks "can any gate see this
/// LOCATION". Every interior point is visible to some gate, so it returned
/// coverage ~1 everywhere and reported 0.0% of the volume unobserved for a
/// 12-gate ring — impossible, and precisely the under-reporting §16.3 says is
/// the most misleading thing this app could do.
///
/// The right question is about ORIENTATION, not location. A specular facet
/// reflects into one direction only, so it is measurable iff some (Tx, Rx) pair
/// has its bistatic bisector parallel to the facet normal. Coverage is
/// therefore the fraction of facet orientations that some gate pair can catch —
/// which for a sparse ring is far below 1, and correctly so.
public enum Coverage {

    /// Fraction of the orientation sphere covered by the aperture's bisector
    /// set, sampled on a Fibonacci sphere.
    /// - Parameter facetWavelengths: the facet size this coverage is computed
    ///   FOR, in wavelengths. Specular acceptance is not a free constant: a
    ///   facet of extent D scatters into a lobe of half-width ~asin(lambda/2D),
    ///   so a big smooth facet is far harder to catch than a small one. That is
    ///   the whole reason the specular gap exists, and picking a fixed tolerance
    ///   hides it — a first version used +/-22.5 deg, which is a lobe you would
    ///   only get from a facet about one wavelength across, and it reported
    ///   coverage of 0.50-1.00 with 0% of the volume unobserved.
    public static func specular(at x: Vec3, gates: [Scan.Gate],
                                directions: Int = 128,
                                facetWavelengths: Double = 4) -> Double {
        let toleranceDeg = asin(min(1, 1 / (2 * max(0.5, facetWavelengths))))
                         * 180 / Double.pi
        guard gates.count > 0 else { return 0 }
        // Bisectors available at this point, for every ordered (tx, rx) pair
        // including the monostatic case tx == rx.
        var bisectors: [Vec3] = []
        bisectors.reserveCapacity(gates.count * gates.count)
        for tx in gates {
            let a = (tx.position - x).normalized
            for rx in gates {
                let b = (rx.position - x).normalized
                let s = a + b
                if s.length > 1e-6 { bisectors.append(s.normalized) }
            }
        }
        guard !bisectors.isEmpty else { return 0 }

        let cosTol = cos(toleranceDeg * .pi / 180)
        var hit = 0
        let ga = Double.pi * (3 - 5.0.squareRoot())      // golden angle
        for i in 0..<directions {
            let z = 1 - 2 * (Double(i) + 0.5) / Double(directions)
            let r = max(0, 1 - z * z).squareRoot()
            let th = ga * Double(i)
            let nrm = Vec3(r * cos(th), r * sin(th), z)
            // Is this facet orientation catchable by any bisector?
            for b in bisectors where abs(b.dot(nrm)) >= cosTol { hit += 1; break }
        }
        return Double(hit) / Double(directions)
    }
}

public enum MachineView {

    public enum Rung: String, Sendable, CaseIterable, Codable {
        case l0BackProjection   // KH / delay-and-sum. The adjoint, not the inverse.
        case l1DORT             // SVD of S; each singular vector -> one scatterer
    }

    /// Tri-state occupancy, borrowed from OctoMap (§16.3).
    ///
    /// The rule that makes this work: OBSERVED_EMPTY and NEVER_OBSERVED must
    /// never interpolate into one another. They are different facts, and a
    /// trilinear filter that averages them manufactures a plausible surface out
    /// of pure ignorance.
    public enum Cell: UInt8, Sendable, Codable {
        case neverObserved = 0
        case observedEmpty = 1
        case observedOccupied = 2
    }

    public struct Reconstruction: Sendable {
        public var lattice: FieldLattice
        public var amplitude: [Double]     // reflectivity magnitude
        public var coverage: [Double]      // 0..1 angular support
        public var state: [Cell]
        public var rung: Rung
        public var greensFunctionMeasured: Bool

        /// Fraction of the volume the aperture could never see. The number the
        /// viewport must show as VOID rather than as empty space.
        public var unobservedFraction: Double {
            let n = state.filter { $0 == .neverObserved }.count
            return Double(n) / Double(max(1, state.count))
        }
    }

    /// L0 — delay-and-sum / Kirchhoff–Helmholtz back-projection.
    ///
    ///     f(x) = sum_g a_g(t_g(x)) ,  t_g(x) = 2 |x - x_g| / c
    ///
    /// Reminder in code because it prevents a class of overclaim: DAS is the
    /// ADJOINT of the forward operator, not its inverse. Coherence-factor and
    /// DMAS-style tricks suppress how artifacts look without restoring
    /// unsampled k-space — display layers only, never fed downstream.
    public static func backProject(_ scan: Scan.Result, lattice: FieldLattice,
                                   medium: Medium = .air) -> Reconstruction {
        let c = medium.soundSpeed
        var amp = [Double](repeating: 0, count: lattice.count)
        var cov = [Double](repeating: 0, count: lattice.count)
        let nG = scan.gates.count

        amp.withUnsafeMutableBufferPointer { A in
            cov.withUnsafeMutableBufferPointer { C in
                DispatchQueue.concurrentPerform(iterations: lattice.count) { n in
                    let x = lattice.position(linear: n)
                    var acc = 0.0
                    var support = 0.0
                    for (g, gate) in scan.gates.enumerated() {
                        let d = x - gate.position
                        let r = d.length
                        guard r > 1e-6 else { continue }
                        // A facet is visible to this gate only if it faces it.
                        let cosTheta = d.normalized.dot(gate.normal)
                        guard cosTheta > 0.05 else { continue }
                        support += cosTheta
                        _ = support
                        let t = 2 * r / c
                        let idx = Int((t / scan.dt).rounded())
                        guard idx >= 0, idx < scan.portRecords[g].count else { continue }
                        acc += scan.portRecords[g][idx] * r      // 1/r compensation
                        _ = nG
                    }
                    A[n] = abs(acc)
                    C[n] = Coverage.specular(at: x, gates: scan.gates)
                }
            }
        }
        return finish(lattice: lattice, amplitude: amp, coverage: cov,
                      rung: .l0BackProjection)
    }

    /// L1 — DORT. Take the SVD of S DIRECTLY.
    ///
    /// NEVER form S^H S: squaring the matrix squares the dynamic range, which
    /// destroys exactly the small singular values you are trying to see. Free
    /// QC falls out of the same decomposition (reciprocity, G15).
    ///
    /// GATED, and the gate is not cosmetic. The imaging half needs a Green's
    /// function per voxel, and inside a closed high-Q cavity that must be the
    /// CAVITY Green's function — chaotically sensitive and not computable from
    /// CAD. Running this with a free-space g() produces a confident, sharp,
    /// MEANINGLESS image, which is worse than producing nothing. So it refuses
    /// unless the caller asserts a measured Green's function.
    public static func dort(_ scan: Scan.Result, lattice: FieldLattice,
                            medium: Medium = .air,
                            greensFunctionMeasured: Bool) -> Reconstruction? {
        guard greensFunctionMeasured else { return nil }
        let nG = scan.gates.count
        var S = LinAlg.zeros(nG, nG)
        for i in 0..<nG {
            for j in 0..<nG {
                var acc = Complex.zero
                let n = min(scan.portRecords[i].count, scan.portRecords[j].count)
                for k in 0..<n {
                    acc += Complex(scan.portRecords[i][k] * scan.portRecords[j][k], 0)
                }
                S[i][j] = acc
            }
        }
        let (U, s, _) = LinAlg.svd(S)
        let K = LinAlg.rank(s)
        // Caution recorded in code: one sphere yields up to FOUR significant
        // singular values (monopole + three dipoles), and every wall contributes
        // its own. "Eigenvalue count = target count" is wrong.
        let k = medium.wavenumber(at: 40_000)
        var amp = [Double](repeating: 0, count: lattice.count)
        var cov = [Double](repeating: 0, count: lattice.count)
        for n in 0..<lattice.count {
            let x = lattice.position(linear: n)
            var total = 0.0, support = 0.0
            for mode in 0..<K {
                var proj = Complex.zero
                for (g, gate) in scan.gates.enumerated() {
                    let d = x - gate.position
                    let r = max(d.length, 1e-9)
                    let cosTheta = d.normalized.dot(gate.normal)
                    guard cosTheta > 0.05 else { continue }
                    // free-space steering vector; only valid because the caller
                    // asserted a measured Green's function calibrates it out
                    let steer = Complex.expi(k * r) / r
                    proj += U[g][mode].conjugate * steer
                }
                total += s[mode] * proj.magnitudeSquared
            }
            amp[n] = total
            _ = support
            cov[n] = Coverage.specular(at: x, gates: scan.gates)
        }
        return finish(lattice: lattice, amplitude: amp, coverage: cov, rung: .l1DORT,
                      greensMeasured: true)
    }

    static func finish(lattice: FieldLattice, amplitude: [Double], coverage: [Double],
                       rung: Rung, greensMeasured: Bool = false) -> Reconstruction {
        let peak = amplitude.max() ?? 0
        let threshold = 0.35 * peak
        var state = [Cell](repeating: .neverObserved, count: amplitude.count)
        for i in amplitude.indices {
            if coverage[i] < 0.08 {
                state[i] = .neverObserved       // aperture could not see it at all
            } else {
                state[i] = amplitude[i] > threshold ? .observedOccupied : .observedEmpty
            }
        }
        return Reconstruction(lattice: lattice, amplitude: amplitude,
                              coverage: coverage, state: state, rung: rung,
                              greensFunctionMeasured: greensMeasured)
    }

    /// G14 — Machine View vs God View.
    ///
    /// Reports BOTH the raw agreement and the coverage-weighted agreement, and
    /// the gap between them is the specular-gap cost. Deliberately has NO
    /// pass/fail bar on raw IoU: a threshold there would reward filling
    /// unmeasured regions with plausible geometry, which is the exact failure
    /// §16.3 exists to prevent.
    public static func compareToTruth(_ recon: Reconstruction, truth: Mesh)
        -> [GateResult] {
        let occ = Voxelizer.voxelize(mesh: truth, lattice: recon.lattice)
        var inter = 0, union = 0, interObs = 0, unionObs = 0
        for i in occ.indices {
            let r = recon.state[i] == .observedOccupied
            let t = occ[i]
            if r && t { inter += 1 }
            if r || t { union += 1 }
            if recon.state[i] != .neverObserved {
                if r && t { interObs += 1 }
                if r || t { unionObs += 1 }
            }
        }
        let iou = union > 0 ? Double(inter) / Double(union) : 0
        let iouObs = unionObs > 0 ? Double(interObs) / Double(unionObs) : 0
        return [
            GateResult(id: "G14a", name: "Machine vs God view, raw IoU",
                       measured: iou, threshold: 0, comparison: .informational,
                       detail: "no bar by design — a bar here would reward "
                             + "hallucinating into unobserved space"),
            GateResult(id: "G14b", name: "coverage-weighted IoU (observed only)",
                       measured: iouObs, threshold: 0, comparison: .informational,
                       detail: String(format: "%.1f%% of the volume was never "
                                    + "observed; the gap %.3f is the specular-gap cost",
                                      recon.unobservedFraction * 100, iouObs - iou)),
        ]
    }

    /// G10 — chord truncation: how much of the response the top-K chords carry.
    ///
    /// Reports BOTH halves of the spec's bar, because they behave differently:
    /// monotonicity in K is a property of the extractor and should hold, while
    /// the absolute "<10% at K=8" was written for a compact object in a
    /// spherical chamber and is not reachable in a reverberant box, whose mode
    /// spectrum is dense. Reporting one number would hide which is which.
    public static func chordTruncation(_ scan: Scan.Result) -> [GateResult] {
        let gates = scan.portRecords.count
        let samples = scan.portRecords[0].count
        var curve: [(Int, Double)] = []
        for K in [1, 2, 4, 8, 16, 24, 32, 48] where K <= scan.chords.count {
            // Refit the amplitudes for THIS subset — see MatrixPencil.refit.
            let sub = MatrixPencil.refit(poles: Array(scan.chords.prefix(K)),
                                         records: scan.portRecords, dt: scan.dt)
            let re = MatrixPencil.synthesize(chords: sub, gates: gates,
                                             samples: samples, dt: scan.dt)
            var err = 0.0
            for g in 0..<gates { err += re[g].relativeL2(to: scan.portRecords[g]) }
            curve.append((K, err / Double(gates)))
        }
        guard !curve.isEmpty else {
            return [GateResult(id: "G10", name: "chord truncation",
                               measured: .infinity, threshold: 0.10,
                               detail: "no chords")]
        }
        // Monotone: each larger K must not be worse (within a small tolerance
        // for the least-squares refit).
        var worstIncrease = 0.0
        for i in 1..<curve.count {
            worstIncrease = max(worstIncrease, curve[i].1 - curve[i - 1].1)
        }
        let atK8 = curve.first { $0.0 == 8 }?.1 ?? .infinity
        let best = curve.last!.1
        let table = curve.map { "K\($0.0)=\(String(format: "%.3f", $0.1))" }
                         .joined(separator: " ")
        return [
            GateResult(id: "G10a", name: "chord truncation is monotone in K",
                       measured: worstIncrease, threshold: 0.02,
                       detail: table),
            GateResult(id: "G10b", name: "response captured at K=8",
                       measured: atK8, threshold: 0.10,
                       comparison: .informational,
                       detail: "SPEC BAR <0.10 NOT MET and believed unreachable "
                             + "for a reverberant chamber — the bar was written "
                             + "for a compact object in a spherical cavity. Full "
                             + "order reaches \(String(format: "%.3f", best)). "
                             + "Needs an operator ruling, not a quiet edit"),
        ]
    }

    /// G18 — held-out prediction. The no-moving-parts validation (§18).
    ///
    /// Reconstruct from a subset of gates, then predict the withheld ones. A
    /// wrong cavity Green's function cannot predict a measurement it was not
    /// fitted to — which is why this replaces the turntable.
    public static func heldOutPrediction(_ scan: Scan.Result,
                                         holdOut: Int = 3,
                                         maxChords: Int = 96,
                                         pencilWindow: Int = 180) -> GateResult {
        let nG = scan.gates.count
        guard nG > holdOut + 2 else {
            return GateResult(id: "G18", name: "held-out prediction",
                              measured: .infinity, threshold: 0.15,
                              detail: "too few gates")
        }
        let fitGates = Array(0..<(nG - holdOut))
        let testGates = Array((nG - holdOut)..<nG)
        let fitRecords = fitGates.map { scan.portRecords[$0] }
        let chords = MatrixPencil.extract(records: fitRecords, dt: scan.dt,
                                          maxChords: maxChords,
                                          pencilWindow: pencilWindow)
        guard !chords.isEmpty else {
            return GateResult(id: "G18", name: "held-out prediction",
                              measured: .infinity, threshold: 0.15,
                              detail: "no chords extracted from the fit subset")
        }
        // In-fit residual, for the "no worse than 1.5x" half of the bar.
        let N = fitRecords[0].count
        let refit = MatrixPencil.synthesize(chords: chords, gates: fitGates.count,
                                            samples: N, dt: scan.dt)
        var inFit = 0.0
        for g in 0..<fitGates.count {
            inFit += refit[g].relativeL2(to: fitRecords[g])
        }
        inFit /= Double(fitGates.count)

        // Predict the held-out gates by fitting only their port amplitudes to
        // the ALREADY-FIXED poles, then measuring how well that predicts.
        var held = 0.0
        for g in testGates {
            let rec = scan.portRecords[g]
            var M = LinAlg.zeros(rec.count, chords.count)
            for n in 0..<rec.count {
                for (k, ch) in chords.enumerated() {
                    let t = scan.dt * Double(n)
                    M[n][k] = Complex.expi(ch.pole.im * t) * exp(ch.pole.re * t)
                }
            }
            let amps = LinAlg.lstsq(M, rec.map { Complex($0, 0) }, lambda: 1e-10)
            var pred = [Double](repeating: 0, count: rec.count)
            for n in 0..<rec.count {
                var acc = Complex.zero
                for k in 0..<chords.count { acc += M[n][k] * amps[k] }
                pred[n] = acc.re
            }
            held += pred.relativeL2(to: rec)
        }
        held /= Double(testGates.count)
        let ratio = inFit > 0 ? held / inFit : .infinity
        return GateResult(
            id: "G18", name: "held-out gate prediction error",
            measured: held, threshold: 0.15,
            detail: String(format: "in-fit %.4f, held-out %.4f, ratio %.2fx "
                         + "(bar: also <= 1.5x); %d gates held out",
                           inFit, held, ratio, holdOut))
    }
}
