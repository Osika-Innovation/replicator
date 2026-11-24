import FieldCore
import Foundation

/// Study S5: what a build must hold. The ring mold is compiled once for the
/// plates as drawn, then the same drive, at the same power, is played on
/// random builds of the plates (`PlateArray.asBuilt`): one kind of error at a
/// time at three sizes, then together, two builds of each. A build passes as
/// the drawing does: every site holds at least a quarter of its fair share
/// (G-M1) and 95 % of the powder ends on the shape (G-M2). Returns the
/// drawing's gates and one informational row per kind of build.
public func runTolerance(ctx: MetalContext, array arr: PlateArray, log: @escaping (String) -> Void = { print($0) }) throws -> [GateResult] {
    let (sites, segments) = moldShape("ring", centre: arr.centre)
    typealias T = PlateArray.Tolerance
    func tol(_ f: (inout T) -> Void) -> T { var t = T(); f(&t); return t }
    var cases: [(String, T, Double)] = []
    for v in [0.02, 0.05, 0.10] { cases.append((String(format: "gain ±%.0f %%", 100 * v), tol { $0.gain = v }, 0)) }
    for v in [5.0, 10, 20] { cases.append((String(format: "phase ±%.0f°", v), tol { $0.phaseDegrees = v }, 0)) }
    for v in [0.05e-3, 0.1e-3, 0.2e-3] { cases.append((String(format: "position ±%.2f mm", v * 1000), tol { $0.position = v }, 0)) }
    for v in [0.001, 0.003, 0.01] { cases.append((String(format: "resonance ±%.1f %%", 100 * v), tol { $0.resonance = v }, 0)) }
    for v in [0.005, 0.02, 0.05] { cases.append((String(format: "%.1f %% dead", 100 * v), tol { $0.dead = v }, 0)) }
    for v in [0.1, 0.3, 1.0] { cases.append((String(format: "air %.1f K warmer", v), T(), v)) }
    // Together: what calibration should leave (tight), and an uncalibrated build (loose).
    cases.append(("calibrated: gain ±2 %, phase ±5°, position ±0.1 mm, 0.5 % dead, air 0.1 K",
                  tol { $0.gain = 0.02; $0.phaseDegrees = 5; $0.position = 0.1e-3; $0.dead = 0.005 }, 0.1))
    cases.append(("as assembled: gain ±10 %, phase ±20°, position ±0.2 mm, resonance ±1 %, 2 % dead, air 1 K",
                  tol { $0.gain = 0.10; $0.phaseDegrees = 20; $0.position = 0.2e-3; $0.resonance = 0.01; $0.dead = 0.02 }, 1))
    var setup = MoldSetup()
    setup.particles = false
    let seeds: [UInt64] = [1, 2]
    for (name, t, dT) in cases { for s in seeds {
        setup.builds.append(("\(name) #\(s)", arr.asBuilt(t, seed: s), Medium.air(temperatureC: 20 + dT, humidity: 50)))
    } }
    let out = try runMold(ctx: ctx, label: "ring", sites: sites, segments: segments, chamber: .plates(arr), setup: setup, log: log)
    var gates = out.gates
    log("\nbuild                                                                    on shape   sites ÷ fair    weakest lift   passes")
    for (i, c) in cases.enumerated() {
        let rs = out.builds[(i * seeds.count)..<((i + 1) * seeds.count)]
        let on = rs.map(\.onShape).min()!, lo = rs.map(\.siteMin).min()!, hi = rs.map(\.siteMax).max()!, lift = rs.map(\.weakestLift).min()!
        let ok = on >= 0.95 && lo >= 0.25
        log(String(format: "%-72@ %5.1f %%    %.2f–%.2f      %.2f×          %@", c.0 as NSString, 100 * on, lo, hi, lift, ok ? "yes" : "NO"))
        gates.append(GateResult(id: "S5", name: "ring mold on a build with \(c.0) (emptiest site ÷ fair share, worst of \(seeds.count) builds)",
                                measured: lo, threshold: 0.25, comparison: .informational,
                                detail: String(format: "%.1f %% on the shape, sites %.2f–%.2f of a fair share, weakest site lifts %.2f× a grain; %@",
                                               100 * on, lo, hi, lift, ok ? "passes G-M1 and G-M2" : "FAILS")))
    }
    // Closed loop: a machine is calibrated before it molds. Take one build
    // with assembly-grade errors as the machine; calibration measures every
    // element's gain and phase (and finds the dead ones), so the compile runs
    // on that machine as measured. What remains is the calibration's own
    // error and the air's drift since: play the drive on the machine plus
    // those.
    let machine = arr.asBuilt(tol { $0.gain = 0.10; $0.phaseDegrees = 20; $0.position = 0.2e-3; $0.resonance = 0.003; $0.dead = 0.02 }, seed: 11)
    let left: [(String, T, Double)] = [
        ("gain ±1 %, phase ±2°, air 0.05 K", tol { $0.gain = 0.01; $0.phaseDegrees = 2 }, 0.05),
        ("gain ±2 %, phase ±5°, air 0.1 K", tol { $0.gain = 0.02; $0.phaseDegrees = 5 }, 0.1),
        ("gain ±5 %, phase ±10°, air 0.3 K", tol { $0.gain = 0.05; $0.phaseDegrees = 10 }, 0.3),
    ]
    var closed = MoldSetup()
    closed.particles = false
    for (name, t, dT) in left { for s in seeds {
        closed.builds.append(("\(name) #\(s)", machine.asBuilt(t, seed: 100 + s), Medium.air(temperatureC: 20 + dT, humidity: 50)))
    } }
    log("\ncalibrated: the mold compiled on one assembled machine as measured (gain ±10 %, phase ±20°, position ±0.2 mm, resonance ±0.3 %, 2 % dead)")
    let cal = try runMold(ctx: ctx, label: "ring, calibrated machine", sites: sites, segments: segments, chamber: .plates(machine), setup: closed, log: log)
    gates += cal.gates
    log("\ncalibration leaves                                                        on shape   sites ÷ fair    weakest lift   passes")
    for (i, c) in left.enumerated() {
        let rs = cal.builds[(i * seeds.count)..<((i + 1) * seeds.count)]
        let on = rs.map(\.onShape).min()!, lo = rs.map(\.siteMin).min()!, hi = rs.map(\.siteMax).max()!, lift = rs.map(\.weakestLift).min()!
        let ok = on >= 0.95 && lo >= 0.25
        log(String(format: "%-72@ %5.1f %%    %.2f–%.2f      %.2f×          %@", c.0 as NSString, 100 * on, lo, hi, lift, ok ? "yes" : "NO"))
        gates.append(GateResult(id: "S5c", name: "ring mold compiled on a calibrated machine, calibration leaving \(c.0) (emptiest site ÷ fair share, worst of \(seeds.count))",
                                measured: lo, threshold: 0.25, comparison: .informational,
                                detail: String(format: "%.1f %% on the shape, sites %.2f–%.2f of a fair share, weakest site lifts %.2f× a grain; %@",
                                               100 * on, lo, hi, lift, ok ? "passes G-M1 and G-M2" : "FAILS")))
    }
    return gates
}
