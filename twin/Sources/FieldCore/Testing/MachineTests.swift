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
        h.test("resonant plate: every pair of element faces keeps its gap, inside the annulus") { t in
            let d = RH1Design(), a = PlateArray.rh1(d)
            let want = (2 * d.elementHoleClearance + d.elementHoleWeb) * 1e-3
            for sites in [a.lowerSites!, a.upperSites!] {
                var least = Double.infinity
                for i in sites.indices { for j in (i + 1)..<sites.count {
                    let gap = ((sites[i].x - sites[j].x) * (sites[i].x - sites[j].x) + (sites[i].y - sites[j].y) * (sites[i].y - sites[j].y)).squareRoot()
                        - sites[i].radius - sites[j].radius
                    least = min(least, gap)
                } }
                t.check(least >= want, String(format: "closest pair %.3f mm apart, want %.3f", least * 1000, want * 1000))
                let r = sites.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }
                t.check(r.min()! >= a.innerRadius - 1e-9 && r.max()! <= a.plateRadius + 1e-9, "a centre left the annulus")
            }
        }
        h.test("a built plate: no tolerance, no change; errors compound; a dead element stays dead") { t in
            let a = PlateArray(perPlate: 60).locked(tones: [60_000, 80_000])
            let same = a.asBuilt(PlateArray.Tolerance(), seed: 3)
            t.check(same.channelError!.allSatisfy { $0 == .one }, "zero tolerance must leave every element as drawn")
            var tol = PlateArray.Tolerance(); tol.dead = 0.2; tol.gain = 0.1
            let first = a.asBuilt(tol, seed: 4)
            let dead = first.channelError!.indices.filter { first.channelError![$0] == .zero }
            t.check(dead.count > 10 && dead.count < 40, "\(dead.count) dead of 120 at 20 %")
            var small = PlateArray.Tolerance(); small.phaseDegrees = 5
            let second = first.asBuilt(small, seed: 5)
            t.check(dead.allSatisfy { second.channelError![$0] == .zero }, "a dead element came back")
            let live = first.channelError!.indices.first { first.channelError![$0] != .zero }!
            t.near(second.channelError![live].magnitude, first.channelError![live].magnitude, 1e-12, "a phase error must not change the gain")
            let g = second.gains([60_000], curve: false)![0]
            t.check(dead.allSatisfy { g[$0] == .zero }, "a dead element plays")
        }
        h.test("emulated backend, resonant elements: a lone scatterer is found through the resonance curves") { t in
            // Each element sends and hears through its own resonance; the
            // controller's matched filter knows the curves, so it still peaks
            // on the scatterer, and an element far off the tone hears little.
            let plate = PlateArray(perPlate: 36).locked(tones: [60_000, 70_000, 80_000])
            let x = plate.centre + Vec3(3e-3, -2e-3, 1e-3)
            var b = EmulatedBackend(array: plate, world: .init(scatterers: [x]))
            let fr = FCodePrograms.codedPulse(array: plate, upperPlate: false, tones: [60_000, 65_000, 70_000, 75_000, 80_000], seed: 5, t: 0, duration: 5e-3)
            let stream = FCodeFile(machine: b.name, calibrationRef: b.calibrationRef, band: b.band, channels: plate.channels, frames: [fr])
            let rec = try b.play(stream)
            let echo = MachineImaging.echo(of: rec.frames[0], sent: fr) { b.transfer(frequency: $0) }
            let at = MachineImaging.match(echo: echo, sent: fr, rxGates: fr.rxGates, at: x, array: plate, medium: b.medium, radius: b.world.radius)
            let off = MachineImaging.match(echo: echo, sent: fr, rxGates: fr.rxGates, at: x + Vec3(4e-3, 0, 0), array: plate, medium: b.medium, radius: b.world.radius)
            t.check(at > 0.99 && off < 0.8, String(format: "match %.3f on the scatterer, %.3f 4 mm aside", at, off))
            let e60 = plate.toneOf!.firstIndex(of: 0)!, e80 = plate.toneOf!.firstIndex(of: 2)!
            let heard = echo[0]                                   // the 60 kHz tone
            t.check(heard[e80].magnitude < 0.2 * heard[e60].magnitude + 1e-30, "an 80 kHz element hears little at 60 kHz")
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
            // A filled face leaves no stretch of a slot arm 8 mm long with 1 mm
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
        h.test("P0: calibration through the backend finds a build's gains and phases, one plate at a time") { t in
            let drawn = PlateArray.p0(), air = RH1Freestanding.roomAir
            var tol = PlateArray.Tolerance(); tol.gain = 0.1; tol.phaseDegrees = 20
            var m = EmulatedBackend(array: drawn.asBuilt(tol, seed: 3), band: [39_000, 41_000])
            m.probes = [drawn.centre]
            t.check(m.describe().channels == drawn.channels + 1, "the probe is a channel")
            // A can exactly as the calibrator draws it: a piston of 5 mm, deaf behind.
            m.probeResponse = { c, k in Complex(c > 0 ? Propagator.pistonDirectivity(k: k, a: 5e-3, cosTheta: c) : 0, 0) }
            let r = try! Calibration.run(&m, array: drawn, medium: air, probe: drawn.centre, probeGate: drawn.channels, velocity: 0.2, date: "") { pass, b in
                b.probeFacing = [Vec3(0, 0, pass == 0 ? -1 : 1)]
            }
            let truth = m.array.channelError!
            for plate in [0..<drawn.perPlate, drawn.perPlate..<drawn.channels] {
                let mean = plate.reduce(Complex.zero) { $0 + truth[$1] } * (1 / Double(plate.count))
                for c in plate { t.check((r.errors[c] * mean - truth[c]).magnitude < 1e-3, "channel \(c)") }   // 16-bit wire
            }
            // The controller's pulse widths: amplitude sin(π w / N), phase kept to a step.
            m.pulse = (512, 2.0)
            let z = m.pulsed(Complex.expi(0.7) * 1.0)
            t.near(z.magnitude, 1.0, 0.02, "amplitude to a width step"); t.near(atan2(z.im, z.re), 0.7, 0.01, "phase to a step")
            t.check(m.pulsed(Complex(1e-4, 0)) == .zero, "under one step: off")
        }
        h.test("desktop calibration: every tone of a body is calibrated, and found (INS-06)") { t in
            var body = BodyResponse.threeInputDemo()
            body.frequencies = [40_000, 44_000]; body.response = [body.response[0], body.response[0]]
            let drawn = body.array(), air = RH1Freestanding.roomAir
            var built = drawn
            let truth = (0..<6).map { Complex.expi(0.3 * Double($0) - 0.6) * (0.8 + 0.07 * Double($0)) }
            built.inputs!.error = truth
            var m = EmulatedBackend(array: built, band: [39_000, 45_000])
            let c = drawn.centre
            // The tilted inputs are silent on the axis: listen at three points off it.
            m.probes = [c + Vec3(3e-3, 2e-3, 1e-3), c + Vec3(-4e-3, 1e-3, -2e-3), c + Vec3(1e-3, -5e-3, 3e-3)]
            let r = try! Calibration.multiTone(&m, array: drawn, medium: air, probe: m.probes[0], probeGate: drawn.driveChannels,
                                               velocity: 10, date: "", extra: Array(m.probes[1...]), headLift: 2)
            t.check(r.frequencies == [40_000, 44_000] && r.headLift == 2, "one record per tone: \(r.frequencies)")
            let mean = truth.reduce(Complex.zero, +) * (1.0 / 6)
            for rec in r.tones { for ch in 0..<6 {
                t.check((rec.errors[ch] * mean - truth[ch]).magnitude < 5e-3, "\(rec.frequency) Hz input \(ch): \((rec.errors[ch] * mean - truth[ch]).magnitude)")
            } }
        }
        h.test("per-tone calibration applies to a body: each tone carries its own input errors (INS-06, #27)") { t in
            var body = BodyResponse.threeInputDemo()
            body.frequencies = [40_000, 44_000]; body.response = [body.response[0], body.response[0]]
            let drawn = body.array(), air = RH1Freestanding.roomAir
            // The built body is off by a different amount at each tone, as a reverberant plate is.
            let truthA: [Complex] = (0..<6).map { (i: Int) -> Complex in Complex.expi(0.3 * Double(i) - 0.6) * (0.8 + 0.07 * Double(i)) }
            let truthB: [Complex] = (0..<6).map { (i: Int) -> Complex in Complex.expi(1.1 - 0.5 * Double(i)) * (1.2 - 0.06 * Double(i)) }
            let truth: [[Complex]] = [truthA, truthB]
            var built = drawn
            built.inputs!.toneError = truth
            t.check(!built.inputs!.errorIsBroadband && drawn.inputs!.errorIsBroadband, "the built body's errors differ by tone")
            var m = EmulatedBackend(array: built, band: [39_000, 45_000])
            let c = drawn.centre
            m.probes = [c + Vec3(3e-3, 2e-3, 1e-3), c + Vec3(-4e-3, 1e-3, -2e-3), c + Vec3(1e-3, -5e-3, 3e-3)]
            let r = try! Calibration.multiTone(&m, array: drawn, medium: air, probe: m.probes[0], probeGate: drawn.driveChannels,
                                               velocity: 10, date: "", extra: Array(m.probes[1...]), headLift: 2)
            let cal = drawn.calibrated(r)
            t.check(drawn.uncalibratedTones(r).isEmpty && cal.inputs!.toneError?.count == 2, "both tones covered")
            // At a point calibration never listened at, the calibrated model is the built
            // body up to one complex factor per tone (the microphone's own gain and delay).
            let x = c + Vec3(-2e-3, 4e-3, -3e-3)
            func mismatch(_ a: PlateArray, _ f: Double) -> Double {
                let raw = drawn.reference(frequency: f, medium: air).gateRow(at: x)
                let got = a.channelRow(raw, frequency: f), want = built.channelRow(raw, frequency: f)
                var num = Complex.zero, den = 0.0, ww = 0.0
                for i in got.indices { num += want[i] * got[i].conjugate; den += got[i].magnitudeSquared; ww += want[i].magnitudeSquared }
                let k = num * (1 / den)
                var err = 0.0
                for i in got.indices { err += (want[i] - k * got[i]).magnitudeSquared }
                return (err / ww).squareRoot()
            }
            let fs: [Double] = [40_000, 44_000]
            for f in fs { let e: Double = mismatch(cal, f); t.check(e < 1e-2, "\(f) Hz: calibrated model off the built body by \(e)") }
            // One broadband vector (the first tone's errors used everywhere) cannot do that.
            var broad = drawn; broad.inputs!.error = r.tones[0].errors
            let fitHere: Double = mismatch(broad, 40_000), fitThere: Double = mismatch(broad, 44_000)
            t.check(broad.inputs!.errorIsBroadband && fitHere < 1e-2, "broadband errors fit the tone they were measured at: \(fitHere)")
            t.check(fitThere > 0.3, "and miss the other tone: \(fitThere)")
            // A record that lacks a tone leaves it as modelled, and says so.
            var half = r; half.tones.removeLast()
            let partial = drawn.calibrated(half)
            t.check(drawn.uncalibratedTones(half) == [44_000], "the missing tone is named: \(drawn.uncalibratedTones(half))")
            let untouched: [Complex] = partial.inputs!.toneError![1]
            let partialFit: Double = mismatch(partial, 40_000)
            t.check(untouched.allSatisfy { $0 == Complex.one } && partialFit < 1e-2, "and stays as modelled")
            // The old single-vector view still reads and writes.
            var one = drawn; one.inputs!.error = truth[0]
            let both: [[Complex]] = one.inputs!.toneError!, first: [Complex] = one.inputs!.error!
            t.check(both == [truthA, truthA] && first == truthA, "error is the same vector at every tone")
            one.inputs!.scaleError { $0 >= 3 ? Complex(0, 1) : nil }
            let turned: [[Complex]] = one.inputs!.toneError!
            let wantTurned: Complex = truthA[4] * Complex(0, 1)
            t.check(turned[1][4] == wantTurned && turned[1][0] == truthA[0], "scaleError turns the named inputs at every tone")
        }
        h.test("desktop calibration: stale after 0.1 K of air or one head lift (INS-20, INS-30)") { t in
            var r = Calibration.ChamberRecord(machine: "desktop", date: "", tones: [], airTemperature: 22.40, headLift: 3)
            t.check(Calibration.stale(r, airTemperature: 22.45, headLift: 3) == nil, "0.05 K: still true")
            t.check(Calibration.stale(r, airTemperature: 22.50, headLift: 3) == nil, "0.10 K: at the tolerance")
            if case .temperatureDrift(let k, _)? = Calibration.stale(r, airTemperature: 22.25, headLift: 3) { t.near(k, 0.15, 1e-9, "drift") }
            else { t.fail("0.15 K must invalidate") }
            t.check(Calibration.stale(r, airTemperature: 22.40, headLift: 4) == .headLifted(since: 1), "a lift invalidates at any temperature")
            t.check(Calibration.stale(r, airTemperature: nil, headLift: 3) == .noTemperature, "no sensor reading: not valid")
            r.airTemperature = nil
            t.check(Calibration.stale(r, airTemperature: 22.4, headLift: 3) == .noTemperature, "calibrated without a temperature: not valid")
            t.near(Calibration.expectedCorrelation(airTempDrift: 0.1), 0.97, 1e-9, "SIM's point at 0.1 K")
            t.near(Calibration.expectedCorrelation(airTempDrift: 0.5), 0.63, 1e-9, "SIM's point at 0.5 K")
            t.near(Calibration.expectedCorrelation(airTempDrift: 0), 1, 1e-12, "no drift")
        }
        h.test("desktop calibration: a comb tone is moved onto a resonance the firmware can play (INS-29)") { t in
            // A plate resonance at 34 kHz, Q 60, beside the 32 kHz comb tone.
            let sweep = stride(from: 28_000.0, through: 36_000, by: 500).map { f -> Calibration.SweepPoint in
                let x = 2 * 60 * (f - 34_000) / 34_000
                return Calibration.SweepPoint(frequency: f, gain: 0.3 + 1 / (1 + x * x).squareRoot())
            }
            let g = { (f: Double) in sweep.first { $0.frequency == f }!.gain }
            let a = Calibration.toneOnResonance(sweep, nominal: 32_000, window: 0.08)
            t.check(a.frequency == 34_000, "onto the resonance: \(a.frequency)")
            t.near(a.authority, g(34_000) / g(32_000), 1e-12, "authority is the gain ratio")
            t.check(a.authority > 1.3 && a.authority < 3.7, "inside SIM's range for this Q: \(a.authority)")
            let b = Calibration.toneOnResonance(sweep, nominal: 32_000, window: 0.08, grid: 8_000)
            t.check(b.frequency == 32_000 && b.authority == 1, "34 kHz is not on an 8 kHz grid: stay")
            let c = Calibration.toneOnResonance(sweep, nominal: 32_000, window: 0.02)
            t.check(c.frequency == 32_000, "outside the window: stay")
            t.check(Calibration.combRetune(sweep, comb: [32_000, 64_000], window: 0.08).map(\.frequency) == [34_000, 64_000], "a tone with no sweep near it keeps its place")
            // Through a machine: resonant elements at 40 kHz, found by sweeping one of them.
            let plate = PlateArray(perPlate: 6).locked(tones: [40_000])
            var m = EmulatedBackend(array: plate, band: [30_000, 50_000])
            m.probes = [plate.centre]
            let heard = try! Calibration.resonanceSweep(&m, channel: 0, probeGate: plate.channels,
                                                        frequencies: stride(from: 36_000.0, through: 44_000, by: 2_000).map { $0 }, velocity: 0.5)
            let on = Calibration.toneOnResonance(heard, nominal: 38_000, window: 0.1)
            t.check(on.frequency == 40_000 && on.authority > 1.3, "the sweep finds the element's own tone: \(on)")
        }
        h.test("moves are ramps; the planner refuses a step, a stale calibration and an open head (INS-23)") { t in
            let plate = PlateArray.p0(), air = RH1Freestanding.roomAir
            var m = EmulatedBackend(array: plate, band: [39_000, 41_000])
            let a = plate.centre, b = plate.centre + Vec3(3e-3, 0, 0)
            let frames = FCodePrograms.ramp(array: plate, medium: air, from: a, to: b, tones: [40_000], t: 0)
            t.check(frames.count == 11, "3 mm in 0.3 mm steps: \(frames.count) frames")
            t.check(zip(frames, frames.dropFirst()).allSatisfy { $1.t > $0.t }, "in time order")
            let ramped = FCodePrograms.largestStep(frames)
            let jump = FCodePrograms.largestStep([frames.first!, frames.last!])
            t.check(ramped < 0.25 && jump > 2 * ramped, "a ramp changes the drive little per frame: \(ramped) against a jump's \(jump)")
            let level = FCodePrograms.rampLevel(frames[0], from: 0, to: 1, steps: 8)
            t.check(level.count == 8 && level[0].tones[0].drive.l2 == 0, "the level starts from nothing")
            t.near(level[7].tones[0].drive.l2, frames[0].tones[0].drive.l2, 1e-12, "and ends at the frame's own")
            t.near(FCodePrograms.largestStep(level), 1, 1e-9, "the first step of a level ramp is from nothing")

            let policy = Calibration.desktopPlannerPolicy
            t.check(policy.version == "Desktop-planner/1" && policy.maxStep == 0.3e-3 && policy.airTempTolerance == 0.1, "the policy is versioned")
            let cal = Calibration.ChamberRecord(machine: m.name, date: "", tones: [], airTemperature: 22, headLift: 0)
            func stream(_ fr: [FCodeFile.Frame]) -> FCodeFile {
                var f = FCodeFile(machine: m.name, calibrationRef: m.calibrationRef, band: m.band, channels: m.channels); f.frames = fr; return f
            }
            func run(_ fr: [FCodeFile.Frame], air: Double? = 22, lift: Int = 0, down: Bool = true, level: Double = 0.5,
                     check: (PortRecords) -> String? = { _ in nil }) -> Calibration.Outcome {
                Calibration.play(stream(fr), on: &m, calibration: cal, airTemperature: air, headLift: lift, headDown: down, level: level, check: check)
            }
            let log0 = m.frameLog.count
            t.check(run(frames, down: false) == .refused(.interlock(level: 0.5)), "head up, above listen level")
            if case .refused(.stale(.temperatureDrift)) = run(frames, air: 22.3) {} else { t.fail("0.3 K of drift must refuse") }
            t.check(run(frames, lift: 1) == .refused(.stale(.headLifted(since: 1))), "a lift since calibration must refuse")
            var far = frames.last!; far.t = frames[0].t + frames[0].duration
            if case .refused(.step) = run([frames[0], far]) {} else { t.fail("a 3 mm jump must refuse") }
            t.check(m.frameLog.count == log0, "a refusal plays nothing")
            if case .played = run(frames) {} else { t.fail("a ramp with a valid calibration must play") }
            t.check(m.frameLog.count > log0, "and it reached the machine")
            if case .played = run([level[0]], down: false, level: 1e-3) {} else { t.fail("listen level plays with the head up") }
            if case .playedAndFailed(let why, _) = run(frames, check: { _ in "the bead did not follow" }) { t.check(why == "the bead did not follow", "the reason is kept") }
            else { t.fail("played and failed is its own outcome") }
        }
        h.test("holo-eq/0.2: the spec's example reads, checks and round-trips; bad files are refused (#40)") { t in
            let json = """
            {"format": "holo-eq/0.2", "version": "0.2.0",
             "provenance": {"status": "SIMULATED", "source": "holo.holo_equation", "method": "min_q_gorkov | scan_svd", "particle_id": "eps_foam_30"},
             "object_frame": {"id": "tetrahedron_3mm", "origin_offset_m": [0.0, 0.0, 0.0], "bound_radius_m": 0.008, "l_max": 6,
                              "frequencies_hz": [32000.0, 64000.0, 96000.0, 128000.0, 160000.0], "ref_sound_speed_ms": 343.0},
             "strokes": [{"stroke_index": 0, "duration_ms": 40.0, "c_nlm_sparse": [{"t": 4, "l": 1, "m": 0, "re": 0.0, "im": 142.5}]}],
             "t_matrix": {"rank": 4, "per_tone": [{"t": 4, "sigma": [1.2e-4, 4.1e-5], "U_re_im": [], "V_re_im": []}]},
             "legacy_port_preview": {"ignored": true}}
            """
            guard let eq = try? HoloEquation.read(Data(json.utf8)) else { t.fail("the spec's example must read"); return }
            t.check(eq.objectFrame.lMax == 6 && eq.modesPerTone == 49 && eq.provenance.particleID == "eps_foam_30", "49 modes per tone at l_max 6")
            let dense: [[Complex]] = eq.dense(stroke: 0)
            t.check(dense.count == 5 && dense[4][HoloEquation.modeIndex(l: 1, m: 0)] == Complex(0, 142.5), "the one mode lands at tone 4, index 2")
            let filled: Int = dense.reduce(0) { $0 + $1.filter { $0 != Complex.zero }.count }
            t.check(filled == 1, "and nothing else is set")
            t.near(eq.duration, 0.040, 1e-12, "one 40 ms stroke")
            let again: HoloEquation? = (try? eq.write()).flatMap { try? HoloEquation.read($0) }
            t.check(again == eq, "write then read is the same equation")
            func refused(_ change: (inout HoloEquation) -> Void) -> Bool {
                var e = eq; change(&e)
                return (try? e.validate()) == nil
            }
            t.check(refused { $0.format = "holo-field/0.1" }, "the superseded format is refused")
            t.check(refused { $0.strokes[0].modes[0].m = 2 }, "|m| > l is refused")
            t.check(refused { $0.strokes[0].modes[0].l = 7 }, "l above l_max is refused")
            t.check(refused { $0.strokes[0].modes[0].t = 5 }, "a tone index past the list is refused")
            t.check(refused { $0.strokes[0].modes.append($0.strokes[0].modes[0]) }, "a mode given twice is refused")
            t.check(refused { $0.strokes[0].modes[0].re = .nan }, "a non-finite amplitude is refused")
            t.check(refused { $0.strokes[0].index = 1 }, "stroke indices must count from 0")
            t.check(refused { $0.objectFrame.lMax = 13 }, "l_max above 12 is refused")
            t.check(refused { $0.tMatrix!.rank = 9 }, "rank above 8 is refused")
            t.check(refused { $0.tMatrix!.perTone[0].sigma = [1e-5, 1e-4] }, "ascending sigma is refused")
            t.check(refused { $0.tMatrix!.perTone[0].u = [[1, 0]] }, "a U of the wrong size is refused")
        }
        h.test("HLEQ v1: Swift writes the bytes the firmware and NumPy read (#40)") { t in
            // 1 stroke x 8 outputs made by NumPy (struct + astype('<f2') + zlib.crc32): 52 bytes.
            let hex = "484c455101000100080000800000803e003c00c0662e003800000000ff7bfffb01000180553555b5484270411914d0e37a165306"
            var wire: [UInt8] = []
            var it = hex.makeIterator()
            while let a = it.next(), let b = it.next() { wire.append(UInt8(String([a, b]), radix: 16)!) }
            guard let pk = try? HLEQPacket.parse(wire, expectedOutputs: 8) else { t.fail("NumPy's packet must parse"); return }
            t.check(pk.strokes == 1 && pk.outputs == 8 && pk.echoNormQ15 == 32768 && pk.verifyTol == 0.25 && pk.flags == 0, "header fields")
            t.check(pk.biases[0][0] == Complex(1, -2) && pk.biases[0][3] == Complex(65504, -65504), "exact f16 values come back")
            // The same numbers from doubles, as NumPy was given them.
            let given: [Complex] = [Complex(1, -2), Complex(0.1, 0.5), Complex(0, 0), Complex(65504, -65504),
                                    Complex(scalbn(1.0, -24), -scalbn(1.0, -24)), Complex(1.0 / 3, -1.0 / 3), Complex(3.14159, 2.71828), Complex(1e-3, -1e3)]
            let mine: [UInt8]? = try? HLEQPacket(biases: [given], verifyTol: 0.25).serialized()
            t.check(mine == wire, "Swift's bytes are NumPy's bytes")
            t.check(HLEQPacket.crc32(Array("123456789".utf8)) == 0xCBF4_3926, "CRC-32 check value")
            let halves: [(Double, UInt16)] = [(1, 0x3C00), (-2, 0xC000), (0.1, 0x2E66), (65504, 0x7BFF), (65520, 0x7C00), (65519.99, 0x7BFF),
                                              (scalbn(1.0, -24), 0x0001), (scalbn(1.0, -25), 0x0000), (scalbn(1.5, -25), 0x0001), (scalbn(1023.5, -24), 0x0400), (-0.0, 0x8000)]
            for (x, want) in halves { let got: UInt16 = HLEQPacket.half(x); t.check(got == want, "half(\(x)) = \(String(got, radix: 16)), expected \(String(want, radix: 16))") }
            // The size the spec quotes, and what must be refused.
            let six: [[Complex]] = (0..<6).map { s in (0..<64).map { i in Complex(0.01 * Double(i) - 0.3, 0.05 * Double(s)) } }
            guard let big = try? HLEQPacket(biases: six, verifyTol: 0.1).serialized() else { t.fail("6 x 64 must serialise"); return }
            t.check(big.count == 1556 && HLEQPacket.byteCount(strokes: 6, outputs: 64) == 1556, "6 strokes x 64 outputs is 1 556 bytes: \(big.count)")
            let back: HLEQPacket? = try? HLEQPacket.parse(big, expectedOutputs: 64)
            t.check(back?.strokes == 6 && (try? back?.serialized()) == big, "parse then serialise is the same bytes")
            func status(_ bytes: [UInt8], _ outputs: Int? = 64) -> HLEQPacket.Invalid? {
                do { _ = try HLEQPacket.parse(bytes, expectedOutputs: outputs); return nil }
                catch let e as HLEQPacket.Invalid { return e } catch { return nil }
            }
            var flipped = big; flipped[700] ^= 0x10
            t.check(status(flipped) == .crc, "one flipped bit fails the CRC")
            t.check(status(Array(big.dropLast())) == .short && status(big + [0]) == .trailing, "length must be exact")
            t.check(status(big, 72) != nil, "a packet for another output width is refused")
            func resealed(_ change: (inout [UInt8]) -> Void) -> [UInt8] {
                var b = Array(big.dropLast(4)); change(&b)
                let c = HLEQPacket.crc32(b)
                return b + (0..<4).map { UInt8((c >> (8 * UInt32($0))) & 0xFF) }
            }
            if case .value = status(resealed { $0[16 + 41] = 0x7E }) {} else { t.fail("a NaN bias with a good CRC must be a value error") }
            if case .value = status(resealed { $0[12] = 0; $0[13] = 0; $0[14] = 0; $0[15] = 0 }) {} else { t.fail("verify tolerance 0 must be a value error") }
            if case .shape = status(resealed { $0[6] = 17 }) {} else { t.fail("17 strokes must be a shape error") }
            t.check((try? HLEQPacket(biases: [[Complex](repeating: Complex(70_000, 0), count: 8)], verifyTol: 0.1).serialized()) == nil, "a bias too large for f16 is not sent")
            t.check((try? HLEQPacket(biases: [[Complex](repeating: Complex(.nan, 0), count: 8)], verifyTol: 0.1).serialized()) == nil, "a NaN bias is not sent")
            t.check((try? HLEQPacket(biases: [[Complex](repeating: .zero, count: 12)], verifyTol: 0.1).serialized()) == nil, "an output count that is not a multiple of 8 is not sent")
        }
        h.test("HLEQ v1: SIM's golden packet holo/runs/hleq_v1_fixture.bin parses and is written back byte for byte (#58)") { t in
            // twin/Sources/FieldCore/Testing/MachineTests.swift -> the repository root
            var root = URL(fileURLWithPath: #filePath)
            for _ in 0..<5 { root.deleteLastPathComponent() }
            guard let data = try? Data(contentsOf: root.appendingPathComponent("holo/runs/hleq_v1_fixture.bin")) else {
                print("    SKIPPED: holo/runs/hleq_v1_fixture.bin not found under \(root.path)"); return
            }
            let wire = [UInt8](data)
            t.check(wire.count == 1556, "the fixture is \(wire.count) bytes, not 1 556")
            guard let pk = try? HLEQPacket.parse(wire, expectedOutputs: 64) else { t.fail("SIM's fixture must parse"); return }
            // the numbers of holo/runs/holo_equation_receipt.json "hleq_fixture"
            t.check(pk.strokes == 6 && pk.outputs == 64 && pk.flags == 1 && pk.echoNormQ15 == 12345 && pk.verifyTol == 0.125, "header fields")
            t.check(HLEQPacket.crc32(wire[0..<1552]) == 0x42DB_485C, "CRC is the receipt's 42db485c")
            let first: Complex = pk.biases[0][0], last: Complex = pk.biases[5][63]
            let off: Double = max(abs(first.re - 0.367919921875), abs(first.im + 0.1937255859375), abs(last.re + 0.57421875), abs(last.im + 0.320068359375))
            t.check(off <= 1e-6, "first and last bias differ from the receipt by \(off)")
            var largest = 0.0
            for row in pk.biases { for z in row { largest = max(largest, abs(z.re), abs(z.im)) } }
            t.check(largest <= 0.8 + 1e-3 && largest > 0.7, "the generator draws 0.8 x uniform(-1, 1): largest part \(largest)")
            let mine: [UInt8]? = try? pk.serialized()
            t.check(mine == wire, "Swift writes the fixture back byte for byte")
            var wrongWidth = false
            do { _ = try HLEQPacket.parse(wire, expectedOutputs: 72) } catch let e as HLEQPacket.Invalid { if case .shape = e { wrongWidth = true } } catch {}
            t.check(wrongWidth, "the fixture is refused for another output width")
            var hit = wire; hit[700] ^= 0x10
            var crc = false
            do { _ = try HLEQPacket.parse(hit, expectedOutputs: 64) } catch let e as HLEQPacket.Invalid { crc = e == .crc } catch {}
            t.check(crc, "a damaged fixture is refused on its CRC")
        }
        h.test("holo-eq/0.2: SIM's writer is read as written: nested U and V, rank 0, extra keys (#58)") { t in
            // t_matrix_block() of holo/holo_equation.py on a rank-2 4 x 4 matrix (rng 58); T[1][2] and T[3][0] from the same run
            let json = """
            {"format": "holo-eq/0.2", "version": "0.2.0",
             "provenance": {"status": "SIMULATED", "source": "holo.holo_equation", "method": "scan_svd", "particle_id": "eps_foam_30", "metrics": {"n_targets": 1}},
             "object_frame": {"id": "t", "origin_offset_m": [0, 0, 0], "bound_radius_m": 0.002, "l_max": 1, "frequencies_hz": [160000.0], "ref_sound_speed_ms": 343.0, "targets_m": [[0, 0, 0]]},
             "strokes": [{"stroke_index": 0, "duration_ms": 10.0, "c_nlm_sparse": []}],
             "t_matrix": {"rank": 2, "per_tone": [{"t": 0, "sigma": [5.54249866476866, 1.6548029017230508], "U_re_im": [[[0.07050987785390506, -0.15299991344369945], [0.2697374827588626, -0.5472234756175838]], [[-0.39052650935628014, -0.7653652126178634], [0.015868617282235542, 0.1153997604110587]], [[0.17368128500166777, -0.3820275037345512], [-0.08462216571701595, -0.32898910632623857]], [[0.22472487866950425, 0.08193318590872155], [-0.6396493281759116, 0.29945489537269754]]], "V_re_im": [[[-0.5641997195907849, -0.0], [0.5632965169383517, -0.0]], [[0.470173062902089, -0.43500121066581127], [-0.14138541243077757, 0.03623987197932869]], [[-0.2215383878596641, -0.05668622478890297], [-0.0996501274335813, -0.1878850118605055]], [[-0.3207152005954055, 0.3409385410671519], [-0.5509006658112373, 0.559170279669088]]]}]}}
            """
            guard let eq = try? HoloEquation.read(Data(json.utf8)) else { t.fail("a file with SIM's nested U and V must read"); return }
            let tone: HoloEquation.TMatrix.Tone = eq.tMatrix!.perTone[0]
            t.check(tone.u.count == 8 && tone.v.count == 8, "2 columns of 4 modes each")
            t.near(tone.u[4][0], 0.2697374827588626, 1e-15, "column 1 starts at entry 4: mode 0's second value")
            guard let T: [[Complex]] = tone.dense() else { t.fail("U diag(sigma) V^H"); return }
            let e1: Double = hypot(T[1][2].re - 0.6814871984517936, T[1][2].im - 0.8029810072937719)
            let e2: Double = hypot(T[3][0].re + 1.2989775559490937, T[3][0].im - 0.022923981802459043)
            t.check(e1 < 1e-12 && e2 < 1e-12, "U diag(sigma) V^H gives back NumPy's T: off by \(e1), \(e2)")
            guard let out = try? eq.write(), let again = try? HoloEquation.read(out) else { t.fail("write and read again"); return }
            t.check(again == eq, "write then read is the same equation")
            let rows: [[[Double]]]? = ((try? JSONSerialization.jsonObject(with: out)) as? [String: Any])
                .flatMap { $0["t_matrix"] as? [String: Any] }.flatMap { $0["per_tone"] as? [[String: Any]] }.flatMap { $0.first?["U_re_im"] as? [[[Double]]] }
            t.check(rows?.count == 4 && rows?[0].count == 2 && rows?[0][1][0] == 0.2697374827588626, "U is written nested, one row per mode, as SIM's reader needs")
            // the flat column-after-column list of the spec's note reads to the same thing
            let small = """
            {"format": "holo-eq/0.2", "version": "0.2.0", "provenance": {"status": "SIMULATED", "source": "s", "method": "m", "particle_id": "p"},
             "object_frame": {"id": "t", "origin_offset_m": [0, 0, 0], "bound_radius_m": 0.002, "l_max": 1, "frequencies_hz": [160000.0], "ref_sound_speed_ms": 343.0},
             "strokes": [{"stroke_index": 0, "duration_ms": 10.0, "c_nlm_sparse": []}],
             "t_matrix": {"rank": 3, "per_tone": [{"t": 0, "sigma": [2.0], "U_re_im": UU, "V_re_im": UU}]}}
            """
            let flatU: HoloEquation? = try? HoloEquation.read(Data(small.replacingOccurrences(of: "UU", with: "[[1, 0], [0, 1], [0, 0], [0.5, 0]]").utf8))
            let nestedU: HoloEquation? = try? HoloEquation.read(Data(small.replacingOccurrences(of: "UU", with: "[[[1, 0]], [[0, 1]], [[0, 0]], [[0.5, 0]]]").utf8))
            t.check(flatU != nil && flatU == nestedU, "one column: the flat list and the nested list are the same equation; rank is a ceiling")
            // a file SIM made, when it is in the checkout: rank 0, no singular values, 59 modes
            var root = URL(fileURLWithPath: #filePath)
            for _ in 0..<5 { root.deleteLastPathComponent() }
            if let data = try? Data(contentsOf: root.appendingPathComponent("holo/runs/holo_eq_one_site.holo.json")) {
                do {
                    let one = try HoloEquation.read(data)
                    t.check(one.objectFrame.lMax == 6 && one.strokes.count == 1 && !one.strokes[0].modes.isEmpty, "SIM's one-site equation: \(one.strokes[0].modes.count) modes")
                } catch { t.fail("holo/runs/holo_eq_one_site.holo.json must read: \(error)") }
            } else { print("    SKIPPED: holo/runs/holo_eq_one_site.holo.json not found") }
            let empty: String = json.replacingOccurrences(of: "\"rank\": 2", with: "\"rank\": 0")
            t.check((try? HoloEquation.read(Data(empty.utf8))) == nil, "rank 0 with singular values is refused")
        }
        h.test("holo-eq/0.3-mm: a file from SIM's writer reads with all five species forms; bad files are refused (#58)") { t in
            // build_multimaterial_holo_eq() of holo/multimaterial_scan.py: the 11 benchmark species, a crystal, a stored medium, a bare formula
            let json = """
            {"format":"holo-eq/0.3-mm","version":"0.3.0","provenance":{"status":"SIMULATED","source":"holo.multimaterial_scan","factorization":"material_response(Z, w) x geometry_multipoles(k)"},"object_frame":{"id":"multi_element_phantom","l_max":6,"acoustic_freqs_hz":[32000.0,64000.0,96000.0,128000.0,160000.0],"em_te_freqs_hz":[2000.0,10000.0,50000.0,200000.0,1000000.0,5000000.0,20000000.0,50000000.0],"em_tm_freqs_hz":[40000000000.0,80000000000.0,122000000000.0,160000000000.0,200000000000.0,240000000000.0]},"species_palette":[{"key":"eps_foam_30"},{"key":"pcl_1145"},{"key":"C_diamond"},{"Z":13},{"Z":14},{"Z":22},{"Z":26},{"Z":29},{"Z":47},{"Z":79},{"Z":83},{"lattice":{"formula":[[11,1],[17,1]],"structure":"rocksalt","a_A":5.64,"K_GPa":24.4,"G_GPa":14.7}},{"medium":{"formula":[[14,1],[8,2]],"density":2200,"K_GPa":36.7,"G_GPa":31.2}},{"formula":[[14,1.0],[8,2.0]],"solid_fraction":0.5}],"sites":[{"r_m":[0.0,0.0,0.0],"radius_m":0.0003,"s":0},{"r_m":[0.001,0.0,0.0],"radius_m":0.0003,"s":1},{"r_m":[0.002,0.0,0.0],"radius_m":0.0003,"s":2},{"r_m":[0.003,0.0,0.0],"radius_m":0.0003,"s":3},{"r_m":[0.004,0.0,0.0],"radius_m":0.0003,"s":4},{"r_m":[0.005,0.0,0.0],"radius_m":0.0003,"s":5},{"r_m":[0.006,0.0,0.0],"radius_m":0.0003,"s":6},{"r_m":[0.007,0.0,0.0],"radius_m":0.0003,"s":7},{"r_m":[0.008,0.0,0.0],"radius_m":0.0003,"s":8},{"r_m":[0.009000000000000001,0.0,0.0],"radius_m":0.0003,"s":9},{"r_m":[0.01,0.0,0.0],"radius_m":0.0003,"s":10},{"r_m":[0.0,0.001,0.0],"radius_m":0.0003,"s":11},{"r_m":[0.0,0.002,0.0],"radius_m":0.0003,"s":12},{"r_m":[0.0,0.003,0.0],"radius_m":0.0003,"s":13}]}
            """
            let eq: HoloEquationMM
            do { eq = try HoloEquationMM.read(Data(json.utf8)) } catch { t.fail("SIM's 0.3-mm file must read: \(error)"); return }
            t.check(eq.palette.count == 14 && eq.sites.count == 14 && eq.objectFrame.lMax == 6, "14 species, 14 sites")
            t.check(eq.objectFrame.acousticFrequencies.count == 5 && eq.objectFrame.emTEFrequencies.count == 8 && eq.objectFrame.emTMFrequencies.count == 6, "three carrier bands")
            t.check(eq.palette[0] == .key("eps_foam_30") && eq.palette[7] == .element(z: 29, solidFraction: nil), "a key and an atomic number")
            if case .lattice(let s, _) = eq.palette[11] {
                t.check(s.structure == "rocksalt" && s.a == 5.64 && s.bulkModulus == 24.4 && s.shearModulus == 14.7 && s.formula == [.init(z: 11, count: 1), .init(z: 17, count: 1)], "the NaCl crystal")
            } else { t.fail("entry 11 is a lattice") }
            if case .medium(let s, _) = eq.palette[12] { t.check(s.density == 2200 && s.formula.map(\.z) == [14, 8] && s.structure == nil, "the stored silica medium") }
            else { t.fail("entry 12 is a medium") }
            t.check(eq.palette[13] == .formula([.init(z: 14, count: 1), .init(z: 8, count: 2)], solidFraction: 0.5), "the bare formula")
            t.check(eq.estimatedSpecies == [13], "only the bare formula is an estimate: \(eq.estimatedSpecies)")
            let again: HoloEquationMM? = (try? eq.write()).flatMap { try? HoloEquationMM.read($0) }
            t.check(again == eq, "write then read is the same equation")
            t.check((try? HoloEquation.read(Data(json.utf8))) == nil, "the 0.2 reader does not take a 0.3-mm file")
            func refused(_ change: (inout HoloEquationMM) -> Void) -> Bool {
                var e = eq; change(&e)
                return (try? e.validate()) == nil
            }
            t.check(refused { $0.format = "holo-eq/0.2" }, "another format is refused")
            t.check(refused { $0.palette[7] = .element(z: 119, solidFraction: nil) }, "Z = 119 is refused")
            t.check(refused { $0.palette[7] = .element(z: 29, solidFraction: 0) }, "a solid fraction of 0 is refused")
            t.check(refused { $0.palette[0] = .key("") }, "an empty key is refused")
            t.check(refused { $0.palette[13] = .formula([], solidFraction: 1) }, "an empty formula is refused")
            t.check(refused { $0.palette[13] = .formula([.init(z: 14, count: -1)], solidFraction: 1) }, "a negative count is refused")
            t.check(refused { if case .lattice(var s, let n) = $0.palette[11] { s.structure = "bct"; $0.palette[11] = .lattice(s, name: n) } }, "an unknown structure is refused")
            t.check(refused { if case .lattice(var s, let n) = $0.palette[11] { s.a = nil; $0.palette[11] = .lattice(s, name: n) } }, "a lattice without a cell edge is refused")
            t.check(refused { if case .medium(var s, let n) = $0.palette[12] { s.density = nil; $0.palette[12] = .medium(s, name: n) } }, "a medium without density is refused")
            t.check(refused { if case .medium(var s, let n) = $0.palette[12] { s.bulkModulus = 0; $0.palette[12] = .medium(s, name: n) } }, "a medium without stiffness is refused")
            t.check(refused { $0.sites[3].species = 14 }, "a site pointing past the palette is refused")
            t.check(refused { $0.sites[3].radius = 0 }, "a site of no size is refused")
            t.check(refused { $0.sites[3].r = [0, 0] }, "a site needs three coordinates")
            t.check(refused { $0.objectFrame.acousticFrequencies = [64000, 32000] }, "descending frequencies are refused")
            t.check(refused { $0.sites = [] } && refused { $0.palette = [] }, "an empty object is refused")
            let two: String = json.replacingOccurrences(of: "{\"Z\":13}", with: "{\"Z\":13,\"key\":\"Al\"}")
            t.check(two != json && (try? HoloEquationMM.read(Data(two.utf8))) == nil, "an entry with two forms is refused")
            let frac: String = json.replacingOccurrences(of: "[[11,1],[17,1]]", with: "[[11.5,1],[17,1]]")
            t.check(frac != json && (try? HoloEquationMM.read(Data(frac.utf8))) == nil, "a fractional atomic number is refused")
        }
        h.test("Bench Gate 0: the firmware's messages and its linewidth estimate (INS-40, #93)") { t in
            // The default plan's start message, as zlib.crc32 and the C host test have it.
            let hex = "4247305300010200004c1a480000a041c9000000998c763b"
            var want: [UInt8] = []
            var it = hex.makeIterator()
            while let a = it.next(), let b = it.next() { want.append(UInt8(String([a, b]), radix: 16)!) }
            t.check(BenchGate0.startMessage(BenchGate0.Plan()) == want, "start message bytes")
            // A point as the firmware writes it.
            var pt: [UInt8] = Array("BG0P".utf8)
            FCodeWire.put(UInt16(7), &pt); FCodeWire.put(UInt16(0), &pt)
            FCodeWire.put(Float(158_140), &pt); FCodeWire.put(Float(1.5), &pt); FCodeWire.put(Float(-2.5), &pt)
            FCodeWire.put(FCodeWire.crc32(pt[...]), &pt)
            let p = try? BenchGate0.parsePoint(pt)
            t.check(p == BenchGate0.Point(index: 7, frequency: 158_140, value: Complex(1.5, -2.5)), "point parses")
            var refused = 0
            for bit in 0..<(8 * pt.count) { var d = pt; d[bit / 8] ^= UInt8(1 << (bit % 8)); if (try? BenchGate0.parsePoint(d)) == nil { refused += 1 } }
            t.check(refused == 8 * pt.count && (try? BenchGate0.parsePoint(Array(pt.dropLast()))) == nil, "every one-bit error and a short point are refused")
            // The Airy comb of a 240 mm cavity at 20 °C: the width and the reflection come back.
            let c = 331.3 * (1 + 20 / 273.15).squareRoot(), gap = 0.240, fsr = c / (2 * gap)
            func sweep(_ r: Double, detune: Double) -> [BenchGate0.Point] {
                let rho = r * r * exp(-2 * BenchGate0.alpha * gap)
                return (0..<201).map { i in
                    let f = 158_000 + 20 * Double(i), x = 2 * Double.pi * (f - 160_000 - detune) / fsr
                    let power = (1 - rho) * (1 - rho) / (1 - 2 * rho * cos(x) + rho * rho)
                    return BenchGate0.Point(index: i, frequency: f, value: Complex(0, 8000 * power.squareRoot()))
                }
            }
            for (r, verdict) in [(0.70, BenchGate0.Verdict.fail), (0.82, .marginal), (0.88, .pass), (0.95, .pass)] {
                guard let fit = BenchGate0.estimate(sweep(r, detune: 123), soundSpeed: c) else { t.fail("no fit at r \(r)"); continue }
                let width = BenchGate0.airyFWHM(rho: r * r * exp(-2 * BenchGate0.alpha * gap), fsr: fsr)
                t.near(fit.fwhm, width, 0.03 * width, "width at r \(r), Hz")
                t.near(fit.rPlaneWave, r, 0.01, "reflection read back at r \(r)")
                t.near(fit.detune, 123, 3, "the resonance is found where it was put")
                t.check(fit.verdict == verdict, "r \(r): \(fit.verdict), expected \(verdict)")
            }
            t.check(BenchGate0.estimate((0..<201).map { BenchGate0.Point(index: $0, frequency: 0, value: Complex(2000, 0)) }, soundSpeed: c) == nil, "a flat response has no resonance")
            // SIM #79's law and #82's width, as the lock uses them.
            t.near(BenchGate0.gapPerKelvin() * 1e3, 0.41, 0.005, "mm of gap per K")
            t.near(BenchGate0.gapCorrection(detune: 170) * 1e3, 0.255, 1e-6, "170 Hz at 160 kHz is 0.255 mm of gap")
            t.near(BenchGate0.rSimAnchor(width: 0.25e-3), 0.88, 1e-9, "SIM's 0.25 mm is 0.88")
        }
        h.test("body response: an aliased export is refused for planning; 0.2 carries what the inputs hear (INS-19)") { t in
            let desk = BodyResponse.desktop200()
            t.check((try? desk.validate()) != nil, "the shipped file still loads")
            t.check(desk.aliased, "96 patches per plate at 160 kHz alias: pitch \(desk.maxPatchPitch * 1e3) mm against \(desk.halfWavelength() * 1e3) mm")
            t.near(desk.halfWavelength(), 343.0 / 320_000, 1e-12, "half a wavelength at the top tone")
            do { try desk.validateForPlanning(); t.fail("an aliased file must not be planned on") }
            catch let e as BodyResponse.Invalid {
                if case .aliased(let pitch, let half, let f) = e { t.check(pitch > 5 * half && f == 160_000, "the error says by how much: \(pitch) m against \(half) m") }
                else { t.fail("wrong error: \(e)") }
            } catch { t.fail("wrong error: \(error)") }
            let data = try! JSONEncoder().encode(desk)
            t.check((try? BodyResponse.read(data)) != nil && (try? BodyResponse.read(data, forPlanning: true)) == nil, "read(forPlanning:) refuses it")
            // The same face sampled finely enough at its top tone passes.
            var fine = BodyResponse.threeInputDemo(side: 6, pitch: 4e-3)       // 40 kHz: half a wavelength is 4.29 mm
            fine.provenance.status = "SIMULATED"
            t.check(!fine.aliased && (try? fine.validateForPlanning()) != nil, "4 mm pitch at 40 kHz: \(fine.maxPatchPitch)")
            var coarse = BodyResponse.threeInputDemo(side: 6, pitch: 5e-3); coarse.provenance.status = "SIMULATED"
            t.check(coarse.aliased, "5 mm pitch at 40 kHz aliases")
            t.check(!BodyResponse.p0Identity().aliased, "a reference set is exempt")
            // Receive path.
            var bad = fine; bad.receive = fine.response
            t.check((try? bad.validate()) == nil, "a receive response in a 0.1 file is refused")
            let rx = fine.withReciprocalReceive()
            t.check(rx.format == "body-response/0.2" && (try? rx.validate()) != nil, "0.2 validates")
            let round = try! BodyResponse.read(try! JSONEncoder().encode(rx))
            t.check(round == rx, "0.2 survives the file")
            t.check(fine.received(pressure: [Complex](repeating: .one, count: fine.patches.count), frequency: 40_000) == nil, "0.1 has no receive path")
            // Reciprocity: what input i hears of the pressure that input j's own patch velocities would be is symmetric in i, j.
            let v = { (i: Int) in fine.response[0][i].map { Complex($0[0], $0[1]) } }
            let h01 = rx.received(pressure: v(1), frequency: 40_000)![0], h10 = rx.received(pressure: v(0), frequency: 40_000)![1]
            t.check((h01 - h10).magnitude <= 1e-12 * max(1, h01.magnitude), "reciprocal: \(h01) against \(h10)")
            var short = rx; short.receive!.removeLast()
            t.check((try? short.validate()) == nil, "a receive response of the wrong shape is refused")
        }
    }
}
