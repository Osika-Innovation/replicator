import Foundation
import FieldCore

/// `fieldc windings` — the second carrier's quasi-static physics: what the
/// CAD's three contrawound winding pairs do in the chambers and the bore.
///
/// Round 13. Until now the windings were solids in the CAD and words in the
/// papers; the twin had no field for them. This command computes it and
/// answers, with numbers: which modes reach the chamber, how many independent
/// channels six circuits buy there, what the windings can lift, and how the
/// coil claims of the St. Clair filings fare where the twin has a handle on
/// them (see ENGINE.md, "Candidate referents, graded").
enum WindingsCommand {

    static let kB = 1.380649e-23, muB = 9.2740100783e-24, eV = 1.602176634e-19
    static let copperResistivity = 1.68e-8
    /// ASSUMED continuous current density for an air-cooled Ø4 mm winding.
    static let continuousCurrentDensity = 5e6          // A/m²

    static func f(_ v: Double, _ digits: Int = 3) -> String { String(format: "%.\(digits)g", v) }
    static func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: max(n, s.count), withPad: " ", startingAt: 0) }
    static func hz(_ v: Double) -> String { v >= 1e6 ? String(format: "%.2f MHz", v * 1e-6) : String(format: "%.0f kHz", v * 1e-3) }

    static func run(_ args: [String]) -> Int32 {
        let t0 = Date()
        let d = RH1Design()
        let w = WindingSet.rh1(d)
        var gates = EMGates.runAll()
        func info(_ id: String, _ name: String, _ v: Double, _ detail: String = "") {
            gates.append(GateResult(id: id, name: name, measured: v, threshold: 0,
                                    comparison: .informational, detail: detail))
        }

        // ---- the circuits ---------------------------------------------------
        let wireArea = Double.pi * pow(d.windingWireDiameter * 1e-3 / 2, 2)
        let iCont = continuousCurrentDensity * wireArea
        print("circuits (from the CAD centrelines; Ø\(Int(d.windingWireDiameter)) mm copper, \(d.windingTurns) turns each):")
        var longest = 0.0
        for c in w.circuits {
            let len = c.filament.length
            longest = max(longest, len)
            print(String(format: "  %@ wire %5.2f m   R_dc %.1f mΩ   %.0f W at %.0f A",
                         pad(c.name, 9) as NSString, len, copperResistivity * len / wireArea * 1e3,
                         copperResistivity * len / wireArea * iCont * iCont, iCont))
        }
        let fQuasi = 299_792_458 / (10 * longest)
        print(String(format: "continuous current (ASSUMED %.0f A/mm²): %.0f A per circuit", continuousCurrentDensity * 1e-6, iCont))
        print(String(format: "quasi-static model valid while the wire is < λ/10: below %.1f MHz (lumped: no capacitance, no skin effect in the wire)", fQuasi * 1e-6))
        info("S-EM0", "quasi-static limit of the winding model (MHz)", fQuasi * 1e-6,
             String(format: "wire %.2f m; continuous %.0f A per circuit (assumed %.0f A/mm²)", longest, iCont, continuousCurrentDensity * 1e-6))

        // ---- where the modes go --------------------------------------------
        let zBuild = (d.chamberFloor + d.chamberCeiling) / 2 * 1e-3
        let zStore = (d.storageFloor + d.storageCeiling) / 2 * 1e-3
        let rTube = d.torusMajorRadius * 1e-3
        func modeField(_ asm: String, _ m: (Double, Double), _ x: Vec3) -> Double {
            var i = [Double](repeating: 0, count: w.circuits.count)
            for (k, c) in w.circuits.enumerated() where c.assembly == asm { i[k] = c.hand > 0 ? m.0 : m.1 }
            return w.field(currents: i, at: x).length
        }
        print("\nmodes of one contrawound pair, field per ampere (µT/A):")
        print("  assembly  mode     in its tube   build-chamber centre   storage-chamber centre")
        var confinement = 0.0
        for a in d.assemblies {
            let tube = Vec3(rTube, 0, a.torusZ * 1e-3)
            for (label, m) in [("ring  ", EMGates.ringMode), ("toroid", EMGates.toroidMode)] {
                let bt = modeField(a.id, m, tube), bb = modeField(a.id, m, Vec3(0, 0, zBuild)),
                    bs = modeField(a.id, m, Vec3(0, 0, zStore))
                print(String(format: "  %@  %@ %12.2f %18.4f %22.4f", pad(a.id, 8) as NSString, label as NSString, bt * 1e6, bb * 1e6, bs * 1e6))
            }
            let ratio = modeField(a.id, EMGates.toroidMode, Vec3(0, 0, zBuild)) / modeField(a.id, EMGates.ringMode, Vec3(0, 0, zBuild))
            confinement = max(confinement, ratio)
        }
        print(String(format: "toroid mode reaches the build-chamber centre at ≤ %.2g of the ring mode's field: it is confined (R5), so it is not a chamber actuator", confinement))
        info("S-EM1", "toroid-mode leakage at the build-chamber centre, relative to the ring mode", confinement,
             "the confined mode couples to what is inside or threads the tube; only the ring mode reaches the chambers")

        // ---- how many channels six circuits buy -----------------------------
        func spectrum(_ columns: [[Vec3]]) -> [Double] {
            let n = columns.count
            var g = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
            for j in 0..<n { for k in j..<n {
                var s = 0.0
                for p in 0..<columns[j].count { s += columns[j][p].dot(columns[k][p]) }
                g[j][k] = s; g[k][j] = s
            } }
            let e = LinAlg.symmetricEigen(g).values.map { max($0, 0).squareRoot() }
            return e.map { $0 / e[0] }
        }
        func combine(_ rows: [[Vec3]], _ m: (Double, Double)) -> [[Vec3]] {
            stride(from: 0, to: rows.count, by: 2).map { j in
                zip(rows[j], rows[j + 1]).map { $0 * m.0 + $1 * m.1 }
            }
        }
        var work: [Vec3] = []
        for ix in -2...2 { for iy in -2...2 { for iz in -2...2 {
            work.append(Vec3(Double(ix) * 6e-3, Double(iy) * 6e-3, zBuild + Double(iz) * 6e-3))
        } } }
        var whole: [Vec3] = []
        for ir in 0...9 { for ip in 0..<8 { for iz in 0...10 {
            let r = Double(ir) * 0.02, p = Double(ip) * Double.pi / 4
            whole.append(Vec3(r * cos(p), r * sin(p),
                              (d.chamberFloor + 20 + Double(iz) * (d.buildChamberHeight - 40) / 10) * 1e-3))
        } } }
        print("\nindependent field patterns (singular values of the current → B map, normalised):")
        var rankIndependent = 0, rankCommon = 0
        for (label, pts) in [("work volume ±12 mm", work), ("whole build chamber", whole)] {
            let rows = w.rows(at: pts)
            let six = spectrum(rows), ring = spectrum(combine(rows, EMGates.ringMode)),
                tor = spectrum(combine(rows, EMGates.toroidMode))
            func line(_ s: [Double]) -> String { s.map { String(format: "%.1e", $0) }.joined(separator: "  ") }
            func count(_ s: [Double]) -> Int { s.filter { $0 > 0.01 }.count }
            print("  \(label):")
            print("    six independent feeds (R5)          \(line(six))   → \(count(six)) above 1 %")
            print("    common wire, wound alike  (3 feeds)  \(line(ring))   → \(count(ring)) above 1 %")
            print("    common wire, wound opposed (3 feeds) \(line(tor))   → \(count(tor)) above 1 % (relative to its own largest)")
            if label.hasPrefix("whole") { rankIndependent = count(six); rankCommon = count(ring) }
        }
        info("S-EM2", "field patterns above 1 % in the build chamber, six independent feeds", Double(rankIndependent),
             "one common wire per pair: \(rankCommon) (and it must choose ring or toroid at build time)")

        // ---- what the windings can lift -------------------------------------
        // −∂(B²)/∂z is a quadratic form in the six currents; its largest
        // eigenvalue is the best lift per unit Σi², and the eigenvector says
        // how to drive. Scale the eigenvector until its largest current is
        // the continuous limit.
        func bestLift(at x: Vec3) -> (lift: Double, currents: [Double], b: Double) {
            let e = LinAlg.symmetricEigen(w.liftForm(at: x))
            let v = e.vectors[0], s = iCont / (v.map(abs).max() ?? 1)
            let i = v.map { $0 * s }
            return (e.values[0] * s * s, i, w.field(currents: i, at: x).length)
        }
        var chamberBest = (lift: 0.0, currents: [Double](), b: 0.0), chamberAt = Vec3.zero
        var bMax = 0.0
        for ir in 0...19 { for iz in 0...45 {
            let x = Vec3(Double(ir) * 0.01, 0, (d.chamberFloor + 5 + Double(iz) * 10) * 1e-3)
            let r = bestLift(at: x)
            if r.lift > chamberBest.lift { chamberBest = r; chamberAt = x }
            // Largest field any drive at the continuous limit can put here.
            let rows = w.circuits.map { Magnetostatics.field(of: $0.filament, at: x) }
            for sign in 0..<32 {
                var b = Vec3.zero
                for (k, row) in rows.enumerated() { b += row * (k == 0 || (sign >> (k - 1)) & 1 == 0 ? iCont : -iCont) }
                bMax = max(bMax, b.length)
            }
        } }
        let centre = bestLift(at: Vec3(0, 0, zBuild))
        var boreBest = (lift: 0.0, currents: [Double](), b: 0.0), boreZ = 0.0
        for iz in stride(from: d.storageFloor - 100, through: d.chamberCeiling + 100, by: 5) {
            let r = bestLift(at: Vec3(0, 0, iz * 1e-3))
            if r.lift > boreBest.lift { boreBest = r; boreZ = iz }
        }
        print(String(format: "\nlift available at the continuous limit, −∂(B²)/∂z in T²/m (best drive of the six circuits at each point):"))
        print(String(format: "  build-chamber centre            %.3g", centre.lift))
        print(String(format: "  best point in the build chamber %.3g   at r %.0f mm, z %.0f mm (B %.2f mT)", chamberBest.lift,
                     chamberAt.radiusXY * 1e3, chamberAt.z * 1e3, chamberBest.b * 1e3))
        print(String(format: "  best point on the axis (bore)   %.3g   at z %.0f mm (B %.2f mT)", boreBest.lift, boreZ, boreBest.b * 1e3))
        print("    drive there (A): " + zip(w.circuits, boreBest.currents).map { String(format: "%@ %+.0f", $0.name as NSString, $1) }.joined(separator: ", "))
        print(String(format: "  largest field anywhere in the build chamber: %.2f mT", bMax * 1e3))
        info("S-EM3", "best static lift in the build chamber at the continuous limit, −∂(B²)/∂z (T²/m)", chamberBest.lift,
             String(format: "r %.0f mm, z %.0f mm; on the axis %.3g at z %.0f mm; largest field %.2f mT",
                    chamberAt.radiusXY * 1e3, chamberAt.z * 1e3, boreBest.lift, boreZ, bMax * 1e3))

        let lift = max(chamberBest.lift, boreBest.lift)
        let statics: [MagneticForce.Material] = [
            .init("pyrolytic graphite (⊥)", density: 2200, chi: -4.5e-4),
            .init("bismuth", density: 9780, chi: -1.66e-4),
            .init("water", density: 998, chi: -9.04e-6),
            .init("PLA (approx.)", density: 1240, chi: -9e-6),
            .init("limestone (calcite)", density: 2710, chi: -1.3e-5),
            .init("granite (quartz)", density: 2650, chi: -1.6e-5),
        ]
        print("\nstatic (diamagnetic) levitation: needed −∂(B²)/∂z against the best the windings offer:")
        print("  material                  needed T²/m   short by     current needed per circuit")
        var limestoneShort = 0.0
        for m in statics {
            let need = MagneticForce.staticLevitationGradient(m), short = need / lift
            if m.name.hasPrefix("limestone") { limestoneShort = short }
            print(String(format: "  %@ %10.0f   %9.2g×   %.2g A", pad(m.name, 24) as NSString, need, short, iCont * short.squareRoot()))
        }
        info("S-SC1", "limestone levitated by the windings: force short by (×)", limestoneShort,
             String(format: "needs %.0f T²/m, the windings offer %.3g at %.0f A; a block changes nothing — force and weight both scale with volume",
                    MagneticForce.staticLevitationGradient(statics[4]), lift, iCont))

        let metals: [MagneticForce.Material] = [
            .init("aluminium", density: 2700, conductivity: 3.5e7),
            .init("copper", density: 8960, conductivity: 5.8e7),
            .init("titanium", density: 4500, conductivity: 2.4e6),
        ]
        let freqs = [10e3, 100e3, 1e6, 2.78e6]
        print("\ninduction (eddy-current) levitation of metal grains: current per circuit (A rms) at the best point")
        print("  (✓ within the continuous limit; * above the quasi-static limit of the model)")
        print(pad("  grain", 22) + freqs.map { fr in String(repeating: " ", count: max(0, 12 - hz(fr).count)) + hz(fr) }.joined())
        var bestMetal = Double.infinity, bestMetalWhat = ""
        for m in metals { for radius in [20e-6, 100e-6, 1e-3] {
            var line = pad("  \(m.name) Ø" + (radius < 5e-4 ? String(format: "%.0f µm", radius * 2e6) : String(format: "%.0f mm", radius * 2e3)), 22)
            for fr in freqs {
                // Amplitude² = 2 × rms², so the rms lift form counts twice.
                let need = MagneticForce.eddyLevitationGradient(m, radius: radius, frequency: fr)
                let i = iCont * (need / (2 * lift)).squareRoot()
                let mark = (i <= iCont ? "✓" : " ") + (fr > fQuasi ? "*" : " ")
                line += String(format: "%10.2g%@", i, mark as NSString)
                if fr <= fQuasi, i < bestMetal { bestMetal = i; bestMetalWhat = "\(m.name) Ø\(f(radius * 2e3, 2)) mm at \(hz(fr))" }
            }
            print(line)
        } }
        info("S-EM4", "least current that induction-levitates a metal grain, within the model (A rms per circuit)", bestMetal,
             "\(bestMetalWhat); continuous limit \(f(iCont, 3)) A — the chambers see one ring turn per winding, the other \(d.windingTurns) turns are confined")

        // ---- energy scales ---------------------------------------------------
        let zeeman = muB * bMax
        print(String(format: "\nenergy a %.2f mT field gives one electron spin: %.2g eV = %.2g × kT at 20 °C = %.2g × a Si–O bond (4.7 eV)",
                     bMax * 1e3, zeeman / eV, zeeman / (kB * 293.15), zeeman / (4.7 * eV)))
        info("S-SC2", "field energy per electron spin at the chamber's largest field, relative to kT", zeeman / (kB * 293.15),
             String(format: "%.2g of a Si–O bond: no softening of stone by this route", zeeman / (4.7 * eV)))

        // ---- the 1:3 ratio ----------------------------------------------------
        // St. Clair, US 2003/0197093: two counter-wound toroidal coils on one
        // wire, the smaller on the centreline of the larger, radii 1:3 ("the
        // magic ratio"). Sweep the ratio and look for anything special at 3.
        print("\ncounter-wound coaxial toroid pair on one wire, outer Ø\(Int(d.torusMajorDiameter)) (per ampere):")
        print("  ratio   his k = 1/R² − 1/r²   B at centre µT   on-axis null mm   peak |∂(B²)/∂z| T²/m")
        let Ro = d.torusMajorRadius * 1e-3, ao = (d.torusTubeRadius + d.windingInnerLayerGap) * 1e-3
        let ratios = [1.5, 2, 2.5, 3, 3.5, 4, 5]
        var centreB: [Double] = [], peaks: [Double] = [], nulls: [Double] = []
        for ratio in ratios {
            let outer = Filament.toroidalHelix(majorRadius: Ro, minorRadius: ao, turns: d.windingTurns, hand: 1)
            let inner = Filament.toroidalHelix(majorRadius: Ro / ratio, minorRadius: ao / ratio, turns: d.windingTurns, hand: -1)
            // One wire, wound in opposite directions: the same current runs
            // the opposite way round the axis in the inner coil.
            func bz(_ z: Double) -> Double {
                Magnetostatics.field(of: outer, at: Vec3(0, 0, z)).z - Magnetostatics.field(of: inner, at: Vec3(0, 0, z)).z
            }
            var null = Double.nan, peak = 0.0, prev = bz(0)
            for k in 1...1000 {
                let z = Double(k) * 0.5e-3, b = bz(z)
                if null.isNaN, b * prev < 0 { null = z - 0.25e-3 }
                peak = max(peak, abs(b * b - prev * prev) / 0.5e-3)
                prev = b
            }
            centreB.append(bz(0)); peaks.append(peak); nulls.append(null)
            print(String(format: "  1:%-4.1f %14.4f %18.3f %16.1f %20.3g", ratio, 1 / (ratio * ratio) - 1, bz(0) * 1e6, null * 1e3, peak))
        }
        func monotonic(_ v: [Double]) -> Bool {
            zip(v, v.dropFirst()).allSatisfy { $0 < $1 } || zip(v, v.dropFirst()).allSatisfy { $0 > $1 }
        }
        let special = [centreB, peaks, nulls].filter { !monotonic($0) }.count
        print("  every column runs smoothly through 1:3" + (special == 0 ? " (all monotonic): the ratio is a dial, not a resonance" : " — \(special) column(s) not monotonic, look again"))
        info("S-SC3", "field quantities with an extremum across the 1:3 radius ratio", Double(special),
             "centre field, on-axis null and peak gradient swept 1:1.5 … 1:5; k = −8/9 is one point on a smooth curve")

        // ---- what would do the bore lift (R10) --------------------------------
        // A coil wound round the bore: every turn is a ring turn. One coil of
        // mean radius a carrying N·I amp-turns; a grain on the axis sits where
        // −∂(B²)/∂z is largest (just above the coil). Amp-turns to hold it.
        print("\na coil round the bore instead (every turn a ring turn): amp-turns (rms) to hold a grain on the axis")
        let coilRadii = [10e-3, 20e-3, 40e-3]
        print(pad("  grain, frequency", 34) + coilRadii.map { a in String(repeating: " ", count: 3) + String(format: "coil Ø%.0f mm", a * 2e3) }.joined())
        var coilLift: [Double] = []
        for a in coilRadii {
            let loop = Filament.loop(radius: a, segments: 360)
            var best = 0.0
            for k in 1...400 {
                let z = Double(k) * a / 100, h = a / 400
                let up = Magnetostatics.field(of: loop, at: Vec3(0, 0, z + h)).z, dn = Magnetostatics.field(of: loop, at: Vec3(0, 0, z - h)).z
                best = max(best, -(up * up - dn * dn) / (2 * h))
            }
            coilLift.append(best)                       // T²/m per (amp-turn)²
        }
        var shotAT = 0.0, powderAT = 0.0
        for (m, radius, fr) in [(metals[0], 1e-3, 100e3), (metals[0], 100e-6, 1e6), (metals[0], 20e-6, 1e6),
                                (metals[1], 1e-3, 100e3), (metals[2], 1e-3, 1e6)] {
            var line = pad("  \(m.name) Ø" + (radius < 5e-4 ? String(format: "%.0f µm", radius * 2e6) : String(format: "%.0f mm", radius * 2e3)) + ", \(hz(fr))", 34)
            for (i, l) in coilLift.enumerated() {
                let at = (MagneticForce.eddyLevitationGradient(m, radius: radius, frequency: fr) / (2 * l)).squareRoot()
                line += String(format: "%14.0f", at)
                if i == 0, m.name == "aluminium", radius == 1e-3 { shotAT = at }
                if i == 0, m.name == "aluminium", radius == 20e-6 { powderAT = at }
            }
            print(line)
        }
        print(String(format: "  a 20-turn Ø20 coil at %.0f A holds Ø2 mm aluminium shot; Ø40 µm powder needs %.0f× the amp-turns — induction lifts shot, not powder",
                     shotAT / 20, powderAT / shotAT))
        info("S-EM5", "amp-turns (rms) for a Ø20 mm bore coil to hold Ø2 mm aluminium shot at 100 kHz", shotAT,
             String(format: "Ø40 µm aluminium powder at 1 MHz: %.0f amp-turns. A bore coil makes R10's induction lift real for millimetre shot only; powder needs the acoustic conveyor", powderAT))

        let r = Receipt(name: "windings", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                        device: deviceName(), gitSHA: gitSHA())
        print("\n" + r.summary)
        if args.contains("--receipt") { writeReceipt(r) }
        return r.allPassed ? 0 : 1
    }
}
