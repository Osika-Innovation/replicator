import Foundation

/// Unit tests for the CAD kernel and the RH-1 solid model.
extension CoreTests {

    static func cad(_ h: TestHarness) {
        h.test("earcut: square with a square hole has the right area") { t in
            let outer = [P2(0, 0), P2(10, 0), P2(10, 10), P2(0, 10)]
            let hole = [P2(3, 3), P2(3, 7), P2(7, 7), P2(7, 3)]
            let tri = Earcut.triangulate(outer: outer, holes: [hole])
            let all = outer + hole
            var a = 0.0
            for k in stride(from: 0, to: tri.count, by: 3) {
                let p = all[Int(tri[k])], q = all[Int(tri[k + 1])], r = all[Int(tri[k + 2])]
                a += abs((q - p).cross(r - p)) / 2
            }
            t.near(a, 100 - 16, 1e-9, "area")
            t.check(tri.count == 8 * 3, "8 triangles for a square annulus, got \(tri.count / 3)")
        }
        h.test("earcut: many holes stay exact") { t in
            let outer = Solid.circle(P2(0, 0), 100, segments: 256)
            var holes: [[P2]] = []
            for i in 0..<60 {
                let r = 20 + Double(i % 6) * 12, a = Double(i) * 2.39996
                holes.append(Solid.circle(P2(r * cos(a), r * sin(a)), 2.5, segments: 12).reversed())
            }
            let tri = Earcut.triangulate(outer: outer, holes: holes)
            let all = outer + holes.flatMap { $0 }
            var a = 0.0
            for k in stride(from: 0, to: tri.count, by: 3) {
                let p = all[Int(tri[k])], q = all[Int(tri[k + 1])], r = all[Int(tri[k + 2])]
                a += abs((q - p).cross(r - p)) / 2
            }
            let expect = abs(signedArea(outer)) - holes.reduce(0) { $0 + abs(signedArea($1)) }
            t.near(a / expect, 1, 1e-9, "area with 60 holes")
        }
        h.test("revolve: closed tube, sector and torus match closed forms") { t in
            let tube = Solid.tube(r0: 40, r1: 50, z0: 0, z1: 30, segments: 720)
            t.check(tube.topology().isClosed, "tube closed")
            t.near(tube.signedVolume / (Double.pi * (2500 - 1600) * 30), 1, 1e-4, "tube volume")
            let sector = Solid.tube(r0: 40, r1: 50, z0: 0, z1: 30, fromDeg: 90, toDeg: 270,
                                    segments: 720)
            t.check(sector.topology().isClosed, "half tube closed (end caps)")
            t.near(sector.signedVolume / (Double.pi * (2500 - 1600) * 15), 1, 1e-4, "half volume")
            let tor = Solid.torus(R: 100, a: 20, zc: 5, tubeSegments: 256, ringSegments: 720)
            t.check(tor.topology().isClosed, "torus closed")
            t.near(tor.signedVolume / (2 * Double.pi * Double.pi * 100 * 400), 1, 1e-3, "torus volume")
            let disc = Solid.tube(r0: 0, r1: 10, z0: 0, z1: 2, segments: 360)
            t.check(disc.topology().isClosed && disc.signedVolume > 0, "disc with a pole closed")
        }
        h.test("extrude with holes and a closed sweep are solids") { t in
            let e = Solid.extrude(outer: [P2(0, 0), P2(20, 0), P2(20, 20), P2(0, 20)],
                                  holes: [Solid.circle(P2(10, 10), 4, segments: 64)],
                                  z0: 0, z1: 5)
            t.check(e.topology().isClosed, "extrusion closed")
            t.near(e.signedVolume, (400 - abs(signedArea(Solid.circle(P2(10, 10), 4, segments: 64)))) * 5,
                   1e-6, "extrusion volume")
            var path: [Vec3] = []
            for i in 0..<400 {
                let a = 2 * Double.pi * Double(i) / 400
                path.append(Vec3(50 * cos(a), 50 * sin(a), 3 * sin(5 * a)))
            }
            let w = Solid.sweepClosed(path: path, radius: 2, sides: 12)
            t.check(w.topology().isClosed && w.signedVolume > 0, "closed sweep is a solid")
        }
        h.test("interference: overlapping boxes caught, touching boxes not") { t in
            let a = Solid.box(center: Vec3(0, 0, 0), size: Vec3(20, 20, 20))
            let b = Solid.box(center: Vec3(15, 0, 0), size: Vec3(20, 20, 20))   // 5 mm overlap
            let c = Solid.box(center: Vec3(20, 0, 0), size: Vec3(20, 20, 20))   // touching
            let q = SolidQuery(a)
            t.check(q.contains(Vec3(0, 0, 0)), "centre inside")
            t.check(!q.contains(Vec3(11, 0, 0)), "outside")
            var over = 0, touch = 0
            for f in b.faces {
                let p = (b.vertices[Int(f.x)] + b.vertices[Int(f.y)] + b.vertices[Int(f.z)]) / 3
                let n = (b.vertices[Int(f.y)] - b.vertices[Int(f.x)])
                    .cross(b.vertices[Int(f.z)] - b.vertices[Int(f.x)]).normalized
                if q.contains(p - n * 0.1) { over += 1 }
            }
            for f in c.faces {
                let p = (c.vertices[Int(f.x)] + c.vertices[Int(f.y)] + c.vertices[Int(f.z)]) / 3
                let n = (c.vertices[Int(f.y)] - c.vertices[Int(f.x)])
                    .cross(c.vertices[Int(f.z)] - c.vertices[Int(f.x)]).normalized
                if q.contains(p - n * 0.1) { touch += 1 }
            }
            t.check(over > 0, "overlap detected")
            t.check(touch == 0, "touching faces are not interference (\(touch))")
        }
        h.test("RH-1 stack: chambers and faces where the documents put them") { t in
            let d = RH1Design()
            t.near(d.buildChamberHeight, 460, 0, "build chamber 1060–1520")
            t.near(d.face("top").faceZ, 1520, 0); t.near(d.face("top").backZ, 1532, 0)
            t.near(d.face("mid-up").backZ, 1048, 0)
            t.near(d.face("mid-down").faceZ, 936, 0, "mirror of mid-up about 998")
            t.near(d.face("top").torusZ, 1575, 0, "spec §8 torus")
            t.near(d.storageFloor, 420, 0, "site FIG.1 deck")
            t.near(d.hornArcLength, 187, 1.0, "mech §3c arc length ≈187")
        }
        h.test("RH-1 model: every part a closed solid, no rule violated") { t in
            let m = RH1Model(detail: .preview)
            for p in m.parts {
                let top = p.mesh.topology()
                t.check(top.isClosed && p.volume > 0, "\(p.name) not a closed solid")
            }
            for r in CADGates.designRules(m) where !r.passed {
                t.fail("\(r.id) \(r.what): \(r.clearance) < \(r.minimum)")
            }
            t.check(m.pattern.sites.count == 380, "380 Vogel sites")
        }
    }
}
