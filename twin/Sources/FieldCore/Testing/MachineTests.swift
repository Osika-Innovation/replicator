import Foundation

/// Unit tests for the machine program layer.
extension CoreTests {

    static func machine(_ h: TestHarness) {
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
            t.check(a.channels == 2 * d.elementCount && a.tag == "rh1x192", "\(a.channels) channels, \(a.tag)")
            for (pat, offset, z) in [(m.pattern, 0, 0.0), (m.patternDown, d.elementCount, a.gap)] {
                for e in pat.elements {
                    let p = els[offset + e.index].position
                    t.near(p.x * 1e3, e.center.x, 1e-9, "x"); t.near(p.y * 1e3, e.center.y, 1e-9, "y"); t.near(p.z, z, 1e-12, "z")
                }
            }
            t.check(m.pattern.elements.allSatisfy { $0.radius - $0.holeRadius > d.boreHoleRadius + 2 }, "clear of the collar hole")
            t.check(m.pattern.slotCenterlines.count > d.slotArms, "slots are dashed: \(m.pattern.slotCenterlines.count) pieces")
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
