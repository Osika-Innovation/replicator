import Foundation

/// The cavity image series, evaluator consistency, and the plate preset.
extension CoreTests {

    static func wallsAndPlates(_ h: TestHarness) {
        h.test("wall images match an explicit alternating-reflection recursion") { t in
            let L = 1.0, z0 = 0.1, R = 0.9
            let w = Propagator.Walls(capSeparation: L, order: 5, reflectionCoefficient: R)
            let got = w.images(of: z0)
            // recursion: reflect in z = 0 then z = L alternately, and vice versa
            var expect: [(Double, Double)] = [(z0, 1)]
            for startAtZero in [true, false] {
                var z = z0, atZero = startAtZero
                for m in 1...5 {
                    z = atZero ? -z : 2 * L - z
                    atZero.toggle()
                    expect.append((z, pow(R, Double(m))))
                }
            }
            t.check(got.count == expect.count, "count \(got.count) vs \(expect.count)")
            for (ez, ew) in expect {
                let match = got.contains { abs($0.z - ez) < 1e-12 && abs($0.weight - ew) < 1e-12 }
                t.check(match, "missing image z=\(ez) w=\(ew)")
            }
            // no image may appear twice (the old series double-counted order 1)
            for i in got.indices { for j in got.indices where j > i {
                t.check(abs(got[i].z - got[j].z) > 1e-12, "duplicate image at \(got[i].z)")
            } }
        }
        h.test("point evaluator matches cached operator with walls and couplings") { t in
            let preset = TestPresets.singlePlate(n: 5)
            let lat = FieldLattice(origin: Vec3(-0.01, -0.01, 0.03), spacing: 0.006,
                                   nx: 3, ny: 3, nz: 3)
            var coupling: [Complex] = []
            for i in preset.elements.indices { coupling.append(Complex.expi(Double(i) * 0.31) * (0.5 + Double(i % 3) * 0.2)) }
            let walls = Propagator.Walls(capSeparation: 0.12, order: 3, reflectionCoefficient: 0.8)
            let prop = Propagator(elements: preset.elements, lattice: lat, frequency: 40_000,
                                  medium: preset.medium, gateCount: preset.gateCount,
                                  elementCoupling: coupling, walls: walls)
            var drive = [Complex](repeating: .zero, count: prop.gateCount)
            for i in drive.indices { drive[i] = Complex.expi(Double(i) * 0.7) }
            let viaOp = prop.forward(drive)
            for n in 0..<lat.count {
                let direct = prop.pressure(at: lat.position(linear: n), drive: drive)
                t.near(viaOp[n].re, direct.re, abs(direct.magnitude) * 1e-9 + 1e-12, "re[\(n)]")
                t.near(viaOp[n].im, direct.im, abs(direct.magnitude) * 1e-9 + 1e-12, "im[\(n)]")
            }
        }
        h.test("plate preset: apertures from the CAD, 6 gates, couplings finite") { t in
            var o = RH1Freestanding.Options()
            o.slotSegment = 0.004
            let (p, c) = RH1Freestanding.preset(o)
            t.check(p.gateCount == 6, "3 throat gates per face × 2 faces")
            t.check(p.elements.count == c.count, "one coupling per element")
            let pat = FacePattern(RH1Design())
            let perGate = p.elements.filter { $0.gateIndex == 0 }.count
            t.check(perGate > pat.drilled.count, "slots add apertures (\(perGate))")
            t.check(c.allSatisfy { $0.magnitude.isFinite && $0.magnitude > 0 }, "finite, nonzero")
            for e in p.elements {
                t.check(e.position.z == 0 || abs(e.position.z - 0.46) < 1e-9, "on a face")
            }
            o.slotsOpen = false
            let (q, _) = RH1Freestanding.preset(o)
            t.check(q.elements.count == 6 * pat.drilled.count, "closed slots: micro-horns only")
        }
    }
}
