import Foundation
import simd
import FieldCore

/// Line/triangle geometry for the machine chrome (§16.2 KNOWN layer).
///
/// This layer is drawn crisp and dimensioned in BOTH Machine View and God View:
/// the machine's own geometry is a specification we know exactly, and rendering
/// it as a reconstruction would be dishonest in the opposite direction.
public struct SceneGeometry {
    public init() {}
    public var linePositions: [SIMD3<Float>] = []
    public var lineColors: [SIMD4<Float>] = []
    public var trianglePositions: [SIMD3<Float>] = []
    public var triangleColors: [SIMD4<Float>] = []

    public mutating func line(_ a: Vec3, _ b: Vec3, _ c: SIMD4<Float>) {
        linePositions.append(SIMD3<Float>(Float(a.x), Float(a.y), Float(a.z)))
        linePositions.append(SIMD3<Float>(Float(b.x), Float(b.y), Float(b.z)))
        lineColors.append(c); lineColors.append(c)
    }

    public mutating func tri(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ col: SIMD4<Float>) {
        for v in [a, b, c] {
            trianglePositions.append(SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z)))
            triangleColors.append(col)
        }
    }

    public mutating func quad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3,
                              _ col: SIMD4<Float>) {
        tri(a, b, c, col); tri(a, c, d, col)
    }

    public mutating func circle(radius: Double, z: Double, segments: Int = 96,
                                color: SIMD4<Float>) {
        for i in 0..<segments {
            let t0 = 2 * Double.pi * Double(i) / Double(segments)
            let t1 = 2 * Double.pi * Double(i + 1) / Double(segments)
            line(Vec3(radius * cos(t0), radius * sin(t0), z),
                 Vec3(radius * cos(t1), radius * sin(t1), z), color)
        }
    }
}

public enum SceneBuilder {

    public struct Palette {
        public var buildVolume = SIMD4<Float>(0.35, 0.65, 0.85, 0.55)
        public var buildVolumeFaint = SIMD4<Float>(0.30, 0.55, 0.75, 0.22)
        public var cap = SIMD4<Float>(0.85, 0.70, 0.35, 0.95)
        public var capFill = SIMD4<Float>(0.26, 0.21, 0.11, 0.55)
        public var panel = SIMD4<Float>(0.45, 0.80, 0.80, 0.90)
        public var panelFill = SIMD4<Float>(0.10, 0.24, 0.26, 0.42)
        public var column = SIMD4<Float>(0.55, 0.57, 0.62, 0.85)
        public var grid = SIMD4<Float>(0.35, 0.37, 0.42, 0.40)
        public var axis = SIMD4<Float>(0.60, 0.62, 0.68, 0.70)
        public var tick = SIMD4<Float>(0.70, 0.72, 0.78, 0.75)
        public var object = SIMD4<Float>(0.92, 0.86, 0.72, 0.95)
        public var objectFill = SIMD4<Float>(0.55, 0.48, 0.34, 0.60)
        public var objectOver = SIMD4<Float>(0.90, 0.40, 0.38, 0.95)
        public init() {}

        public static var light: Palette {
            var p = Palette()
            p.buildVolume = SIMD4<Float>(0.15, 0.35, 0.60, 0.65)
            p.buildVolumeFaint = SIMD4<Float>(0.20, 0.40, 0.60, 0.25)
            p.cap = SIMD4<Float>(0.60, 0.45, 0.10, 1.0)
            p.capFill = SIMD4<Float>(0.88, 0.82, 0.66, 0.55)
            p.panel = SIMD4<Float>(0.15, 0.45, 0.48, 0.95)
            p.panelFill = SIMD4<Float>(0.78, 0.88, 0.88, 0.45)
            p.column = SIMD4<Float>(0.35, 0.37, 0.42, 0.90)
            p.grid = SIMD4<Float>(0.55, 0.57, 0.62, 0.45)
            p.axis = SIMD4<Float>(0.35, 0.37, 0.42, 0.75)
            p.tick = SIMD4<Float>(0.30, 0.32, 0.38, 0.80)
            p.object = SIMD4<Float>(0.30, 0.26, 0.16, 1.0)
            p.objectFill = SIMD4<Float>(0.72, 0.66, 0.52, 0.70)
            p.objectOver = SIMD4<Float>(0.75, 0.20, 0.18, 1.0)
            return p
        }
    }

    /// Triangles of a loaded object, flat-shaded and lightly wired so the
    /// geometry reads against a wireframe-heavy scene. `fits == false` colours
    /// it as a fit violation rather than drawing it as though it were fine.
    public static func object(_ mesh: Mesh, palette: Palette = Palette(),
                              fits: Bool = true) -> SceneGeometry {
        var g = SceneGeometry()
        let fill = fits ? palette.objectFill : palette.objectOver
        let edge = fits ? palette.object : palette.objectOver
        let light = Vec3(0.4, -0.7, 0.6).normalized
        for t in mesh.triangles {
            let lambert = 0.45 + 0.55 * max(0, t.normal.dot(light))
            g.tri(t.a, t.b, t.c,
                  SIMD4<Float>(fill.x * Float(lambert), fill.y * Float(lambert),
                               fill.z * Float(lambert), fill.w))
        }
        for (i, t) in mesh.triangles.enumerated() where i % 7 == 0 {
            g.line(t.a, t.b, edge); g.line(t.b, t.c, edge); g.line(t.c, t.a, edge)
        }
        return g
    }

    /// The RH-1 machine, drawn to the canonical build-sheet dimensions so the
    /// silhouette matches the Blender renders.
    public static func rh1(palette: Palette = Palette(),
                           showPanels: Bool = true,
                           showColumns: Bool = true,
                           doorAngleDeg: Double = 180) -> SceneGeometry {
        var g = SceneGeometry()
        let mm = 0.001
        let bvR = RH1.Dim.buildVolumeDiameter / 2 * mm
        let bvH = RH1.Dim.buildVolumeHeight * mm
        let plateR = RH1.Dim.plateDiameter / 2 * mm
        let boreR = RH1.Dim.boreDiameter / 2 * mm

        // ---- caps: annulus fill + spiral grating hint + bore ----
        for (z, isLower) in [(0.0, true), (bvH, false)] {
            // Only the lower cap is filled. The upper one stays wireframe so the
            // build volume is visible from above — a slicer whose build plate you
            // cannot see into is not a slicer.
            if isLower {
                let seg = 96
                for i in 0..<seg {
                    let t0 = 2 * Double.pi * Double(i) / Double(seg)
                    let t1 = 2 * Double.pi * Double(i + 1) / Double(seg)
                    g.quad(Vec3(boreR * cos(t0), boreR * sin(t0), z),
                           Vec3(plateR * cos(t0), plateR * sin(t0), z),
                           Vec3(plateR * cos(t1), plateR * sin(t1), z),
                           Vec3(boreR * cos(t1), boreR * sin(t1), z),
                           palette.capFill)
                }
            }
            g.circle(radius: plateR, z: z, color: palette.cap)
            g.circle(radius: boreR, z: z, color: palette.cap)
            // 12-arm equiangular spiral slot grating, r(phi) = r0 e^{cot(a) phi}
            let r0 = RH1.Dim.spiralInnerRadius * mm
            let r1 = RH1.Dim.spiralOuterRadius * mm
            let turns = RH1.Dim.spiralTurns
            let cotA = log(r1 / r0) / (turns * 2 * Double.pi)
            for arm in 0..<RH1.Dim.spiralArms {
                let phase = 2 * Double.pi * Double(arm) / Double(RH1.Dim.spiralArms)
                var prev: Vec3? = nil
                for s in 0...28 {
                    let phi = turns * 2 * Double.pi * Double(s) / 28.0
                    let r = r0 * exp(cotA * phi)
                    let p = Vec3(r * cos(phi + phase), r * sin(phi + phase), z)
                    if let q = prev { g.line(q, p, palette.cap) }
                    prev = p
                }
            }
        }

        // ---- the six phononic panels at r = 155 ----
        if showPanels {
            let rP = RH1.Dim.panelRadius * mm
            let w = RH1.Dim.panelWidth * mm
            let span = Double.pi                      // rear 180 deg arcade
            for p in 0..<RH1.Dim.panelCount {
                let frac = (Double(p) + 0.5) / Double(RH1.Dim.panelCount)
                let az = Double.pi - span / 2 + frac * span
                let tangent = Vec3(-sin(az), cos(az), 0)
                let c = Vec3(rP * cos(az), rP * sin(az), 0)
                let a = c - tangent * (w / 2), b = c + tangent * (w / 2)
                g.quad(a, b, b + Vec3(0, 0, bvH), a + Vec3(0, 0, bvH), palette.panelFill)
                g.line(a, b, palette.panel)
                g.line(a + Vec3(0, 0, bvH), b + Vec3(0, 0, bvH), palette.panel)
                g.line(a, a + Vec3(0, 0, bvH), palette.panel)
                g.line(b, b + Vec3(0, 0, bvH), palette.panel)
                // hex-screen banding: cells grade large (low f) at the bottom to
                // small (high f) at the top — the rainbow-trapping axis.
                for band in 1..<8 {
                    let t = Double(band) / 8.0
                    let z = bvH * t
                    g.line(a + Vec3(0, 0, z), b + Vec3(0, 0, z),
                           SIMD4<Float>(palette.panel.x, palette.panel.y,
                                        palette.panel.z, 0.25 + 0.35 * Float(1 - t)))
                }
            }
        }

        // ---- seven arcade columns, 40 x 20 mm at r = 160 ----
        if showColumns {
            let rC = RH1.Dim.columnRadius * mm
            let wT = RH1.Dim.columnTangential * mm
            for c in 0..<RH1.Dim.columnCount {
                let az = Double.pi - Double.pi / 2
                    + Double.pi * Double(c) / Double(RH1.Dim.columnCount - 1)
                let tangent = Vec3(-sin(az), cos(az), 0)
                let base = Vec3(rC * cos(az), rC * sin(az), 0)
                for s in [-wT / 2, wT / 2] {
                    let p = base + tangent * s
                    g.line(p, p + Vec3(0, 0, bvH), palette.column)
                }
            }
        }

        // ---- the build volume: the viewport's subject ----
        g.circle(radius: bvR, z: 0, color: palette.buildVolume)
        g.circle(radius: bvR, z: bvH, color: palette.buildVolume)
        for i in 0..<24 {
            let t = 2 * Double.pi * Double(i) / 24
            g.line(Vec3(bvR * cos(t), bvR * sin(t), 0),
                   Vec3(bvR * cos(t), bvR * sin(t), bvH), palette.buildVolumeFaint)
        }
        // Height ticks every 50 mm, longer every 100.
        var z = 0.0
        while z <= bvH + 1e-9 {
            let major = (z * 1000).rounded().truncatingRemainder(dividingBy: 100) == 0
            g.line(Vec3(bvR, 0, z), Vec3(bvR + (major ? 0.012 : 0.006), 0, z),
                   major ? palette.tick : palette.grid)
            z += 0.05
        }
        // Deck grid.
        let step = 0.035
        var x = -bvR
        while x <= bvR + 1e-9 {
            let h = (bvR * bvR - x * x)
            if h > 0 {
                let y = h.squareRoot()
                g.line(Vec3(x, -y, 0), Vec3(x, y, 0), palette.grid)
                g.line(Vec3(-y, x, 0), Vec3(y, x, 0), palette.grid)
            }
            x += step
        }
        // Axis (the bore sightline / the 13th port).
        g.line(Vec3(0, 0, -0.02), Vec3(0, 0, bvH + 0.02), palette.axis)
        return g
    }
}

// MARK: - Field and trap overlays

extension SceneBuilder {

    /// Perceptually-ordered magnitude ramp. The Swift twin of `magnitudeRamp`
    /// in render.metal — deliberately NOT phase-as-hue, which does not survive
    /// alpha compositing (§16.3).
    public static func ramp(_ t: Double) -> SIMD4<Float> {
        let x = Float(min(1, max(0, t)))
        let stops: [SIMD3<Float>] = [
            SIMD3(0.04, 0.05, 0.12), SIMD3(0.10, 0.25, 0.55),
            SIMD3(0.20, 0.65, 0.70), SIMD3(0.95, 0.75, 0.30),
            SIMD3(1.00, 0.98, 0.90),
        ]
        let seg = min(3, Int(x * 4))
        let f = x * 4 - Float(seg)
        let c = stops[seg] + (stops[seg + 1] - stops[seg]) * f
        return SIMD4<Float>(c.x, c.y, c.z, 0.55)
    }

    /// A slice of |p| through the volume, as coloured quads.
    ///
    /// Computed once per compile and uploaded once — not read back per frame,
    /// so the spirit of the no-readback viewport ruling (§8) holds even though
    /// the colouring happens on the CPU. A per-frame animated field would need
    /// the `sliceFragment` shader path instead.
    public static func fieldSlice(magnitude: [Double], lattice: FieldLattice,
                                  axis: Int = 1, sliceIndex: Int? = nil)
        -> SceneGeometry {
        var g = SceneGeometry()
        guard !magnitude.isEmpty else { return g }
        // Log-compress: node-to-antinode dynamic range is enormous and a linear
        // ramp shows only the antinode.
        let peak = magnitude.max() ?? 1
        guard peak > 0 else { return g }
        let d = lattice.spacing / 2

        func emit(_ centre: Vec3, _ value: Double, _ u: Vec3, _ v: Vec3) {
            let t = log(1 + 10 * value / peak) / log(11.0)
            let c = ramp(t)
            g.quad(centre - u * d - v * d, centre + u * d - v * d,
                   centre + u * d + v * d, centre - u * d + v * d, c)
        }

        switch axis {
        case 0:   // x = const, plane spans y,z
            let i = sliceIndex ?? lattice.nx / 2
            guard i >= 0 && i < lattice.nx else { return g }
            for k in 0..<lattice.nz {
                for j in 0..<lattice.ny {
                    emit(lattice.position(i, j, k),
                         magnitude[lattice.index(i, j, k)],
                         Vec3(0, 1, 0), Vec3(0, 0, 1))
                }
            }
        case 2:   // z = const, plane spans x,y
            let k = sliceIndex ?? lattice.nz / 2
            guard k >= 0 && k < lattice.nz else { return g }
            for j in 0..<lattice.ny {
                for i in 0..<lattice.nx {
                    emit(lattice.position(i, j, k),
                         magnitude[lattice.index(i, j, k)],
                         Vec3(1, 0, 0), Vec3(0, 1, 0))
                }
            }
        default:  // y = const, plane spans x,z — the default "front" cut
            let j = sliceIndex ?? lattice.ny / 2
            guard j >= 0 && j < lattice.ny else { return g }
            for k in 0..<lattice.nz {
                for i in 0..<lattice.nx {
                    emit(lattice.position(i, j, k),
                         magnitude[lattice.index(i, j, k)],
                         Vec3(1, 0, 0), Vec3(0, 0, 1))
                }
            }
        }
        return g
    }

    /// Trap markers: a local minimum of the Gor'kov potential is where a
    /// positive-contrast particle is actually held. Size encodes trap depth, so
    /// a shallow parasitic trap reads as visibly weaker than the intended one.
    public static func traps(_ traps: [(position: Vec3, depth: Double)],
                             palette: Palette = Palette()) -> SceneGeometry {
        var g = SceneGeometry()
        guard let deepest = traps.map(\.depth).max(), deepest > 0 else { return g }
        for t in traps {
            let rel = t.depth / deepest
            let r = 0.0015 + 0.0045 * rel
            // Warm for a strong trap, cool for a weak one.
            let c = SIMD4<Float>(Float(0.35 + 0.6 * rel), Float(0.85 - 0.25 * rel),
                                 Float(0.95 - 0.65 * rel), Float(0.55 + 0.45 * rel))
            let p = t.position
            g.line(p - Vec3(r, 0, 0), p + Vec3(r, 0, 0), c)
            g.line(p - Vec3(0, r, 0), p + Vec3(0, r, 0), c)
            g.line(p - Vec3(0, 0, r), p + Vec3(0, 0, r), c)
            // Small diamond so it reads at a distance.
            let a = Vec3(r, 0, 0), b = Vec3(0, r, 0), cc = Vec3(0, 0, r)
            g.line(p + a, p + b, c); g.line(p + b, p - a, c)
            g.line(p - a, p - b, c); g.line(p - b, p + a, c)
            g.line(p + a, p + cc, c); g.line(p + cc, p - a, c)
        }
        return g
    }
}

extension SceneBuilder {

    /// Particles, coloured by state: cool grey while still feedstock, hot orange
    /// in transit while molten, settling to the material colour once latched.
    public static func particles(_ sim: ParticleSim) -> SceneGeometry {
        var g = SceneGeometry()
        let r = 0.0018
        for p in sim.particles {
            // Temperature drives the glow so the thermal state is legible.
            let hot = Float(min(1, max(0, (p.temperature - 300) / 200)))
            let c: SIMD4<Float>
            switch p.state {
            case .feedstock:
                c = SIMD4<Float>(0.55, 0.57, 0.60, 0.75)
            case .inTransit:
                c = SIMD4<Float>(0.95, 0.45 + 0.35 * (1 - hot), 0.25, 0.95)
            case .trapped:
                c = SIMD4<Float>(0.92 - 0.25 * (1 - hot), 0.86, 0.72, 1.0)
            }
            // A tiny 3-axis cross reads as a point at any zoom without needing
            // point sprites.
            g.line(p.position - Vec3(r, 0, 0), p.position + Vec3(r, 0, 0), c)
            g.line(p.position - Vec3(0, r, 0), p.position + Vec3(0, r, 0), c)
            g.line(p.position - Vec3(0, 0, r), p.position + Vec3(0, 0, r), c)
        }
        return g
    }

    /// The boundary state: per-element drive painted onto the surfaces.
    ///
    /// Brightness is |u| for that element's gate. This is the v0.2 "screen
    /// renderer" idea mapped onto RH-1's eight faces instead of a Goldberg
    /// sphere — and it is what makes a compile legible as something the
    /// *boundary* does, rather than a field that appears by magic.
    public static func boundary(elements: [Element], drive: [Complex],
                                palette: Palette = Palette()) -> SceneGeometry {
        var g = SceneGeometry()
        guard !drive.isEmpty else { return g }
        let peak = drive.map(\.magnitude).max() ?? 1
        guard peak > 0 else { return g }
        for e in elements {
            guard e.gateIndex >= 0 && e.gateIndex < drive.count else { continue }
            let u = drive[e.gateIndex]
            let amp = Float(u.magnitude / peak)
            // Phase as a slight hue shift only — NOT as the primary channel,
            // because hue does not survive alpha compositing (§16.3).
            let ph = Float((u.phase + Double.pi) / (2 * Double.pi))
            let c = SIMD4<Float>(0.30 + 0.65 * amp,
                                 0.55 + 0.35 * amp * (0.6 + 0.4 * ph),
                                 0.45 + 0.45 * amp * (1 - ph),
                                 0.25 + 0.70 * amp)
            // A quad on the element's own surface patch.
            let s = e.equivalentRadius * 0.9
            let n = e.normal
            var t = Vec3(0, 0, 1).cross(n)
            if t.length < 1e-6 { t = Vec3(1, 0, 0) }
            t = t.normalized
            let b = n.cross(t).normalized
            let p = e.position + n * 0.0004     // lift off the surface
            g.quad(p - t * s - b * s, p + t * s - b * s,
                   p + t * s + b * s, p - t * s + b * s, c)
        }
        return g
    }
}

extension SceneBuilder {

    /// A chord, drawn as what it is: a complex frequency plus the GATE PATTERN
    /// that addresses it (§3). Each gate gets a radial bar whose length is
    /// |r_k| for that gate, so the port-vector is legible as a shape on the
    /// boundary rather than as a row of numbers.
    ///
    /// This is the half that breaks the isospectral ambiguity — a bare
    /// eigenfrequency list cannot tell two different objects apart, the
    /// port-vectors can.
    public static func chords(gates: [Scan.Gate], chord: MatrixPencil.Chord,
                              rank: Int = 0, palette: Palette = Palette())
        -> SceneGeometry {
        var g = SceneGeometry()
        guard !chord.portVector.isEmpty else { return g }
        let peak = chord.portVector.map(\.magnitude).max() ?? 1
        guard peak > 0 else { return g }
        // Fade successive chords so the top-weighted one dominates.
        let fade = Float(max(0.25, 1.0 - 0.18 * Double(rank)))
        for (i, gate) in gates.enumerated() {
            guard i < chord.portVector.count else { break }
            let a = chord.portVector[i]
            let len = 0.004 + 0.045 * (a.magnitude / peak)
            let dir = gate.normal.normalized
            let base = gate.position
            let tip = base + dir * len
            // Phase tints; amplitude carries the signal (hue does not composite).
            let ph = Float((a.phase + Double.pi) / (2 * Double.pi))
            let c = SIMD4<Float>(0.45 + 0.5 * ph, 0.80 - 0.2 * ph,
                                 0.95 - 0.4 * ph, fade)
            g.line(base, tip, c)
            // Cap so short bars still read.
            let s = 0.003
            g.line(tip - Vec3(s, 0, 0), tip + Vec3(s, 0, 0), c)
            g.line(tip - Vec3(0, 0, s), tip + Vec3(0, 0, s), c)
        }
        return g
    }
}
