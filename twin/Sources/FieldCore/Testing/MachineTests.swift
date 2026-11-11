import Foundation

/// Unit tests for the machine program layer.
extension CoreTests {

    static func machine(_ h: TestHarness) {
        h.test("element: the bought 40 kHz transmitter's source gives its datasheet level in the engine") { t in
            // 120 dB at 30 cm on axis at 10 V rms. The source was derived with
            // the far-field formula; the engine's piston must give it back.
            let air = RH1Freestanding.roomAir
            let s = ElementSpec.openType40k(medium: air)
            let el = Element(position: .zero, normal: Vec3(0, 0, 1), area: Double.pi * s.radius * s.radius, surface: .lowerCap, gateIndex: 0)
            let prop = Propagator(elements: [el], lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                  frequency: 40_000, medium: air, gateCount: 1)
            let v = s.sourcePerVolt * 10 / el.area
            let p = prop.pressure(at: Vec3(0, 0, 0.3), drive: [Complex(v, 0)]).magnitude * exp(air.absorption(at: 40_000) * 0.3)
            let dB = 20 * log10(p / 2.0.squareRoot() / 20e-6)
            t.near(dB, 120, 0.3, "level at 30 cm, 10 V rms")
            t.near(s.maxVelocity(at: 40_000), 2.0, 0.15, "face velocity at 9 V rms, m/s peak")
        }
        h.test("element: a directly radiating piezo disc is far below its resonances and far too slow") { t in
            let s = ElementSpec.bulkDisc(diameter: 5e-3, thickness: 2e-3)
            t.check(ElementSpec.lowestResonance(diameter: 5e-3, thickness: 2e-3) > 4 * 100_000, "quasi-static across 50–100 kHz")
            // d33 · 800 V rms · √2 · ω at 75 kHz
            t.near(s.maxVelocity(at: 75_000), 2 * Double.pi * 75_000 * 225e-12 * 800 * 2.0.squareRoot(), 1e-6, "m/s peak")
            t.check(s.maxVelocity(at: 100_000) < 0.2, "under 0.2 m/s at the top of the band")
        }
        h.test("element: scaling keeps the face velocity; a resonant element plays its own tone") { t in
            let air = RH1Freestanding.roomAir
            let a = ElementSpec.openType40k(medium: air), b = ElementSpec.scaled(to: 80_000, medium: air)
            t.near(b.maxVelocity(at: 80_000), a.maxVelocity(at: 40_000), 1e-9, "same face velocity")
            t.near(b.maxSource(at: 80_000), a.maxSource(at: 40_000) / 4, 1e-12, "a quarter of the source")
            t.near(b.maxSource(at: 80_000 * (1 + 1 / (2 * b.q))) / b.maxSource(at: 80_000), 1 / 2.0.squareRoot(), 0.01, "−3 dB at f₀(1 + 1/2Q)")
            let plate = PlateArray(perPlate: 90).locked(tones: [50_000, 75_000, 100_000])
            let counts = (0..<3).map { q in plate.toneOf!.filter { $0 == q }.count }
            t.check(counts.allSatisfy { abs($0 - 60) <= 4 }, "the tones share the elements evenly: \(counts)")
            let g = plate.gains([75_000, 77_000], curve: true)!
            let e = plate.toneOf!.firstIndex(of: 1)!
            t.near(g[0][e].magnitude, 1, 1e-12, "unit gain on its tone")
            t.check(g[1][e].magnitude < 0.65 && g[1][e].magnitude > 0.55, "2.7 % off its tone at Q 25: \(g[1][e].magnitude)")
            t.near(plate.pistonRadius(e), 5e-3 * 40 / 75, 1e-12, "radius follows the tone")
            // Every tone's elements must be spread round the plate, not gathered in a wedge.
            let big = PlateArray(perPlate: 900).locked(tones: (0..<9).map { 50_000 + 5_000 * Double($0) })
            let els = big.elements()
            for q in 0..<9 {
                var sx = 0.0, sy = 0.0, n = 0.0
                for c in 0..<900 where big.toneOf![c] == q {
                    let a = atan2(els[c].position.y, els[c].position.x)
                    sx += cos(a); sy += sin(a); n += 1
                }
                t.check((sx * sx + sy * sy).squareRoot() / n < 0.25, "tone \(q) sits in a wedge: mean direction \((sx * sx + sy * sy).squareRoot() / n)")
            }
        }
        h.test("machine gates pass (G-FC1…5)") { t in
            for g in MachineGates.runAll() { t.check(g.passed, g.line) }
        }
        h.test("fcode: a reader rejects what a machine must not play") { t in
            let (_, good) = MachineGates.fixture(perPlate: 6)
            t.check((try? good.validate()) != nil, "the demo stream is valid")
            var f = good; f.version = "pattern/0.2"
            t.check((try? f.validate()) == nil, "wrong version")
            f = good; f.frames[1].tones[0].re.removeLast()
            t.check((try? f.validate()) == nil, "a tone short of one channel")
            f = good; f.frames[0].rxGates.append(good.channels)
            t.check((try? f.validate()) == nil, "an rx gate that is not a channel")
            f = good; f.frames[2].t = 0.001
            t.check((try? f.validate()) == nil, "frames out of order")
            f = good; f.frames[1].tones[0].frequency = 5_000
            t.check((try? f.validate()) == nil, "a tone outside the band")
            f = good; f.frames[1].tones[0].im[0] = .nan
            t.check((try? f.validate()) == nil, "a drive that is not a number")
        }
        h.test("fcode ↔ ChordDrive: verbs and tones survive") { t in
            let chord = ChordDrive(tones: [.init(frequency: 40_000, gates: [Complex(1, 2), Complex(-3, 0.5)])],
                                   verb: .dissolve, rxGates: [1])
            let fr = FCodeFile.Frame(t: 0, duration: 1, chord: chord)
            t.check(fr.verb == .remove, "dissolve is REMOVE")
            t.check(fr.chord.tones[0].gates == chord.tones[0].gates && fr.chord.rxGates == [1], "drive and rx gates")
        }
        h.test("frame log: truncation and trailing bytes are errors") { t in
            let (_, f) = MachineGates.fixture(perPlate: 6)
            let w = try FCodeWire.encode(f)
            t.check((try? FCodeWire.decode(Array(w.dropLast(3)))) == nil, "truncated")
            t.check((try? FCodeWire.decode(w + [0])) == nil, "trailing byte")
            t.check(FCodeWire.crc32(Array("123456789".utf8)[...]) == 0xCBF4_3926, "CRC-32 check value")
        }
        h.test("emulated backend: a focus frame focuses, a wrong channel count is refused") { t in
            let b = EmulatedBackend(array: PlateArray(perPlate: 24))
            let fr = FCodePrograms.focus(array: b.array, medium: b.medium, at: b.array.centre, tones: [40_000], t: 0, duration: 1)
            let prop = b.array.reference(frequency: 40_000, medium: b.medium)
            let d = fr.tones[0].drive
            let at = prop.pressure(at: b.array.centre, drive: d).magnitude
            let off = prop.pressure(at: b.array.centre + Vec3(6e-3, 0, 0), drive: d).magnitude
            t.check(at > 3 * off, String(format: "focus %.0f Pa vs %.0f Pa 6 mm aside", at, off))
            var small = EmulatedBackend(array: PlateArray(perPlate: 6))
            let f = FCodePrograms.demo(backend: b)
            t.check((try? small.play(f)) == nil, "48-channel stream on a 12-channel machine")
        }
        h.test("the machine's plates are the CAD's: same sites, on the plate, clear of the slots") { t in
            let d = RH1Design(), a = PlateArray.rh1(d), m = RH1Model(design: d, detail: .preview)
            let els = a.elements()
            t.check(a.channels == 2 * d.elementCount && a.tag == "rh1x\(d.elementCount)t\(d.elementTones.count)", "\(a.channels) channels, \(a.tag)")
            for (pat, offset, z) in [(m.pattern, 0, 0.0), (m.patternDown, d.elementCount, a.gap)] {
                for e in pat.elements {
                    let p = els[offset + e.index].position
                    t.near(p.x * 1e3, e.center.x, 1e-9, "x"); t.near(p.y * 1e3, e.center.y, 1e-9, "y"); t.near(p.z, z, 1e-12, "z")
                }
            }
            t.check(m.pattern.elements.allSatisfy { $0.radius - $0.holeRadius > d.boreHoleRadius + 2 }, "clear of the collar hole")
            // 1,536 elements leave no stretch of a slot arm 8 mm long with 1 mm
            // of metal to every hole: the dense face has no light slots (OPEN).
            var sparse = d; sparse.elementCount = 192
            t.check(FacePattern(sparse).slotCenterlines.count > d.slotArms, "192 elements: the slots are dashed")
            t.check(m.pattern.slotCenterlines.isEmpty, "\(d.elementCount) elements: \(m.pattern.slotCenterlines.count) slot pieces left")
            t.check(CADGates.engineArray(m).passed, CADGates.engineArray(m).line)
        }
        h.test("plate array from the v0.4 face: the drilled micro-horns, mirrored plates") { t in
            let d = RH1Design.microHornFace, a = PlateArray.fromCAD(d)
            let drilled = FacePattern(d).drilled.count
            t.check(a.perPlate == drilled && a.channels == 2 * drilled, "\(a.perPlate) per plate")
            let els = a.elements()
            t.near(a.gap, d.buildChamberHeight * 1e-3, 1e-12, "gap is the build chamber")
            t.check(els[0].position.x == els[drilled].position.x && els[drilled].position.z == a.gap, "same pattern on both plates")
            t.check(els.allSatisfy { $0.position.radiusXY + $0.equivalentRadius <= d.plateRadius * 1e-3 }, "every element on the plate")
        }
    }
}
