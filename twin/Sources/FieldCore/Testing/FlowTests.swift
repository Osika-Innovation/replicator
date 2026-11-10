import Foundation

/// Unit tests for the traced flow.
extension CoreTests {

    static func flow(_ h: TestHarness) {
        h.test("traced flow: a bowl under gravity — every grain rests where the lift is its weight") { t in
            let n = 33, sp = 0.5e-3
            let lat = FieldLattice(origin: Vec3(-8e-3, -8e-3, -8e-3), spacing: sp, nx: n, ny: n, nz: n)
            let k = 2.0                                    // J/m² per unit power
            let U = lat.positions.map { 0.5 * k * $0.lengthSquared }
            let weight = 3e-3, power = 1.0
            let starts = [Vec3(4e-3, -3e-3, 5e-3), Vec3(-5e-3, 2e-3, -4e-3), Vec3(0, 6e-3, 1e-3), Vec3(1e-3, 1e-3, -6e-3)]
            let ends = FlowMap.trace(U: U, lattice: lat, power: power, weight: weight, starts: starts)
            let rest = Vec3(0, 0, -weight / (power * k))   // 1.5 mm below the bowl's centre
            for (s, e) in zip(starts, ends) {
                t.check(e != nil, "start \(s) stays in the box")
                if let e { t.near((e - rest).length, 0, 0.02e-3, "rest point from \(s)") }
            }
        }
        h.test("traced flow: no hold — the grain leaves; shares recirculate through the top layer") { t in
            let n = 17, sp = 1e-3
            let lat = FieldLattice(origin: Vec3(-8e-3, -8e-3, -8e-3), spacing: sp, nx: n, ny: n, nz: n)
            let U = [Double](repeating: 0, count: lat.count)
            let ends = FlowMap.trace(U: U, lattice: lat, power: 1, weight: 1e-3, starts: [Vec3(0, 0, 0)])
            t.check(ends[0] == nil, "a grain in no field falls out")
            let a = Vec3(1, 0, 0), b = Vec3(2, 0, 0)
            let s = FlowMap.shares(box: [a, nil, nil, b], top: [a, a, b, nil], recirculate: true)
            let atA = s.filter { $0.x == a }.reduce(0) { $0 + $1.share }, atB = s.filter { $0.x == b }.reduce(0) { $0 + $1.share }
            t.near(atA, 0.25 + 0.5 * 2 / 3, 1e-12, "site a: direct + fallen × top share")
            t.near(atB, 0.25 + 0.5 * 1 / 3, 1e-12, "site b")
        }
        h.test("traced flow: sideways drift during a fall, which a 26-neighbour pointer misses") { t in
            // A steady sideways force of a fifth of the weight: the grain
            // drifts 2 mm aside in a 10 mm fall.
            let n = 41, sp = 0.5e-3
            let lat = FieldLattice(origin: Vec3(-10e-3, -10e-3, -10e-3), spacing: sp, nx: n, ny: n, nz: n)
            let weight = 1e-3
            // U = −0.2 w x (push toward +x) + a stiff floor below z = −5 mm.
            let U = lat.positions.map { p -> Double in
                -0.2 * weight * p.x + (p.z < -5e-3 ? 0.5 * 4.0 * (p.z + 5e-3) * (p.z + 5e-3) : 0)
            }
            // 82 steps of a quarter cell: the fall, stopped before the floor.
            let fall = FlowMap.trace(U: U, lattice: lat, power: 1, weight: weight, starts: [Vec3(-6e-3, 0, 5e-3)], step: 0.25, maxSteps: 82)[0]
            if let f = fall {
                let drift = (f.x + 6e-3) / max(5e-3 - f.z, 1e-9)
                t.near(drift, 0.2, 0.01, "sideways drift per unit fall")
            } else { t.fail("left the box during the fall") }
            // The lattice pointer from the same start goes straight down: slope 0.2 < tan 22.5°.
            var c = lat.index(8, 20, 30), moved = 0
            let E = lat.positions.enumerated().map { U[$0.offset] + weight * $0.element.z }
            for _ in 0..<8 {
                var best = c, bs = 0.0
                for dk in -1...1 { for dj in -1...1 { for di in -1...1 where !(di == 0 && dj == 0 && dk == 0) {
                    let m = c + di + dj * n + dk * n * n
                    let s = (E[m] - E[c]) / (Double(di * di + dj * dj + dk * dk).squareRoot() * sp)
                    if s < bs { bs = s; best = m }
                } } }
                if (best % n) != (c % n) { moved += 1 }
                c = best
            }
            t.check(moved == 0, "the 26-neighbour descent does not drift sideways at all (moved \(moved) of 8 steps)")
        }
    }
}
