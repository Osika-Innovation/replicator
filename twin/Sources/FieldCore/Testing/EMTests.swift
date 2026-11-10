import Foundation

/// Unit tests for the winding field solver.
extension CoreTests {

    static func em(_ h: TestHarness) {
        h.test("biot–savart: a long straight wire gives μ0 I / 2πd") { t in
            let f = Filament(points: [Vec3(0, 0, -500), Vec3(0, 0, 500)], closed: false)
            let b = Magnetostatics.field(of: f, at: Vec3(0.1, 0, 0))
            t.near(b.y / (Magnetostatics.mu0 / (2 * Double.pi * 0.1)), 1, 1e-6, "B_φ")
            t.near(b.x, 0, 1e-18, "no radial field"); t.near(b.z, 0, 1e-18, "no axial field")
        }
        h.test("biot–savart: reversing a filament reverses its field") { t in
            let f = Filament.toroidalHelix(majorRadius: 0.1, minorRadius: 0.02, turns: 12)
            let g = Filament(points: f.points.reversed())
            let x = Vec3(0.03, -0.02, 0.05)
            t.near((Magnetostatics.field(of: f, at: x) + Magnetostatics.field(of: g, at: x)).length, 0, 1e-18, "sum")
        }
        h.test("winding gates pass (G-EM1…3)") { t in
            for g in EMGates.runAll() { t.check(g.passed, g.line) }
        }
        h.test("windings come from the CAD: six circuits, mirrored pairs") { t in
            let d = RH1Design(), w = WindingSet.rh1(d)
            t.check(w.circuits.count == 6, "\(w.circuits.count) circuits")
            let a = w.circuits[0].filament.points, b = w.circuits[1].filament.points
            let zc = d.assemblies[0].torusZ * 1e-3
            t.near(a[7].z - zc, (zc - b[7].z) * (d.torusTubeRadius + d.windingInnerLayerGap)
                   / (d.torusTubeRadius + d.windingOuterLayerGap), 1e-12, "B is A mirrored in the torus plane")
            let len = w.circuits[0].filament.length
            t.check(len > 8 && len < 12, String(format: "feed A wire length %.2f m", len))
        }
        h.test("symmetric eigen-solver: known spectrum, orthonormal vectors") { t in
            let A = [[4.0, 1, 2], [1, 3, 0], [2, 0, 5]]
            let (val, vec) = LinAlg.symmetricEigen(A)
            t.near(val.reduce(0, +), 12, 1e-12, "trace")
            for (l, v) in zip(val, vec) {
                for i in 0..<3 {
                    t.near((0..<3).reduce(0.0) { $0 + A[i][$1] * v[$1] }, l * v[i], 1e-10, "A v = λ v")
                }
                t.near(v.reduce(0) { $0 + $1 * $1 }, 1, 1e-12, "unit vector")
            }
            t.check(val[0] >= val[1] && val[1] >= val[2], "descending")
        }
        h.test("eddy polarisability: both limits and the seam between series and closed form") { t in
            t.near(MagneticForce.eddyPolarizability(radiusOverSkinDepth: 0.01) / (-(4.0 / 105) * 1e-8), 1, 1e-6, "small grain")
            t.near(MagneticForce.eddyPolarizability(radiusOverSkinDepth: 1e4), -1.5, 1e-3, "perfect screen")
            let x = 0.4, u = 2 * x
            let closed = -1.5 * (1 - (3 / u) * (sinh(u) - sin(u)) / (cosh(u) - cos(u)))
            t.near(MagneticForce.eddyPolarizability(radiusOverSkinDepth: x) / closed, 1, 1e-5, "seam at a/δ = 0.4")
            var last = 0.0
            for k in 1...60 {
                let a = MagneticForce.eddyPolarizability(radiusOverSkinDepth: 0.1 * Double(k))
                t.check(a < last, "monotonic at a/δ = \(0.1 * Double(k))"); last = a
            }
        }
        h.test("static levitation: water needs B·dB/dz ≈ 1400 T²/m (the 16 T frog)") { t in
            let water = MagneticForce.Material("water", density: 998, chi: -9.04e-6)
            let bdb = MagneticForce.staticLevitationGradient(water) / 2
            t.check(bdb > 1300 && bdb < 1450, String(format: "B·dB/dz = %.0f T²/m", bdb))
        }
    }
}
