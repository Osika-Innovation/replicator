import FieldCore
import Foundation
import Metal

/// The open-air plate array as a field the force compiler can work on
/// (`ForceCompiler.ForceField`), matrix-free on the GPU (ENGINE.md).
///
/// Nothing per element is stored: `potential` evaluates p and ∇p on the
/// lattice for the given drives (one pass over elements × images per point),
/// and `adjoint` returns ∂/∂g* of a weighted sum of U for every element (one
/// threadgroup per element, over the points that carry weight). So the
/// channel count can be thousands; the cost per pass is points × elements ×
/// images. Kernels: `arrayForward`, `arrayAdjoint` (Shaders/array.metal);
/// reference: `PlateArray.reference(…).gateGradientRows` (gate G-A1).
public final class ArrayFieldGPU: ForceCompiler.ForceField {
    public let lattice: FieldLattice
    public let channels: Int
    public let frequencies: [Double]
    public let medium: Medium
    public var toneCount: Int { frequencies.count }
    /// Resonant elements (`PlateArray.gains`): what each element makes of a
    /// drive at each tone, [tone][channel]; nil = broadband. `fields` applies
    /// it, so a drive is what the electronics send and a compile can only
    /// move what the plate can play.
    public let gain: [[Complex]]?
    /// Resonant elements: the largest amplitude a compile may give one
    /// element, as a multiple of the rms over all of them. Every element has
    /// the same face-velocity ceiling, so a drive that leans on a few of them
    /// wastes the rest; nil = no ceiling.
    public var amplitudeCap: Double? = nil
    let ctx: MetalContext
    let elementBuffer: MTLBuffer
    let walls: Propagator.Walls
    let latticePoints: [SIMD4<Float>]
    /// Points per GPU submission (keeps each command buffer short).
    static let chunk = 8_192
    // Working buffers, allocated once and reused: per-call allocations were
    // kept alive by the command buffers and grew ~0.4 GB/s in a compile loop.
    let driveBuf: MTLBuffer, pointBuf: MTLBuffer, outBuf: MTLBuffer, aBuf: MTLBuffer, gradBuf: MTLBuffer

    /// - Parameter curve: for resonant elements, use the resonance curve at
    ///   every frequency (a scan) instead of one tone per element (a mold).
    /// - Parameter equalise: with `curve`, the curves equalised to this floor
    ///   (`PlateArray.gains`).
    public init(ctx: MetalContext, array: PlateArray, frequencies: [Double], medium: Medium,
                lattice: FieldLattice, curve: Bool = false, equalise: Double? = nil) throws {
        self.ctx = ctx; self.lattice = lattice; self.frequencies = frequencies; self.medium = medium
        let els = array.elements()
        self.channels = els.count
        self.walls = array.walls
        self.gain = array.gains(frequencies, curve: curve, equalise: equalise)
        let recs: [ElementPF] = els.map { e in
            ElementPF(
                position: SIMD4(Float(e.position.x), Float(e.position.y), Float(e.position.z), 0),
                normal: SIMD4(Float(e.normal.x), Float(e.normal.y), Float(e.normal.z), 0),
                area: Float(e.area), equivalentRadius: Float(e.equivalentRadius),
                coupling: SIMD2(1, 0), gateIndex: Int32(e.gateIndex),
                monopole: e.directivity == .monopole ? 1 : 0)
        }
        guard let eb = ctx.device.makeBuffer(bytes: recs, length: max(1, recs.count) * MemoryLayout<ElementPF>.stride,
                                             options: .storageModeShared) else { throw MetalContext.Error.noDevice }
        self.elementBuffer = eb
        self.latticePoints = lattice.positions.map { SIMD4(Float($0.x), Float($0.y), Float($0.z), 0) }
        let dev = ctx.device, c = ArrayFieldGPU.chunk, f2 = MemoryLayout<SIMD2<Float>>.stride
        guard let d = dev.makeBuffer(length: max(1, els.count) * f2, options: .storageModeShared),
              let p = dev.makeBuffer(length: c * MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared),
              let o = dev.makeBuffer(length: c * 4 * f2, options: .storageModeShared),
              let a = dev.makeBuffer(length: c * 4 * f2, options: .storageModeShared),
              let g = dev.makeBuffer(length: max(1, els.count) * f2, options: .storageModeShared)
        else { throw MetalContext.Error.noDevice }
        driveBuf = d; pointBuf = p; outBuf = o; aBuf = a; gradBuf = g
    }

    struct ArrParams {
        var pointCount: UInt32
        var elementCount: UInt32
        var order: Int32
        var k: Float
        var prefactorMag: Float
        var alpha: Float
        var capSeparation: Float
        var reflection: Float
    }

    func params(tone t: Int, points n: Int) -> ArrParams {
        let f = frequencies[t]
        let k = medium.wavenumber(at: f)
        return ArrParams(pointCount: UInt32(n), elementCount: UInt32(channels), order: Int32(walls.order),
                         k: Float(k), prefactorMag: Float(medium.density * medium.soundSpeed * k / (2 * .pi)),
                         alpha: Float(medium.absorption(at: f)), capSeparation: Float(walls.capSeparation),
                         reflection: Float(walls.reflectionCoefficient))
    }

    /// p and ∇p for one tone's drive at points, layout [n·4 + c].
    public func fields(_ sent: [Complex], tone t: Int, points: [SIMD4<Float>]) throws -> [Complex] {
        precondition(sent.count == channels)
        let drive = playable(sent, tone: t)
        let dp = driveBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: channels)
        for e in 0..<channels { dp[e] = SIMD2(Float(drive[e].re), Float(drive[e].im)) }
        var out = [Complex](repeating: .zero, count: points.count * 4)
        var start = 0
        while start < points.count {
            let n = min(ArrayFieldGPU.chunk, points.count - start)
            let pp = pointBuf.contents().bindMemory(to: SIMD4<Float>.self, capacity: n)
            for i in 0..<n { pp[i] = points[start + i] }
            var P = params(tone: t, points: n)
            try ctx.dispatch("arrayForward", count: n) { enc in
                enc.setBuffer(outBuf, offset: 0, index: 0)
                enc.setBuffer(elementBuffer, offset: 0, index: 1)
                enc.setBuffer(driveBuf, offset: 0, index: 2)
                enc.setBuffer(pointBuf, offset: 0, index: 3)
                enc.setBytes(&P, length: MemoryLayout<ArrParams>.stride, index: 4)
            }
            let h = outBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: n * 4)
            for i in 0..<(n * 4) { out[start * 4 + i] = Complex(Double(h[i].x), Double(h[i].y)) }
            start += n
        }
        return out
    }

    public func fields(_ drive: [Complex], tone t: Int, at points: [Vec3]) throws -> [Complex] {
        try fields(drive, tone: t, points: points.map { SIMD4(Float($0.x), Float($0.y), Float($0.z), 0) })
    }

    /// What the elements make of a tone's drive (their velocities).
    public func playable(_ drive: [Complex], tone t: Int) -> [Complex] {
        guard let g = gain?[t] else { return drive }
        return drive.indices.map { drive[$0] * g[$0] }
    }

    public var entries: Int {
        guard let gain else { return channels * toneCount }
        return gain.reduce(0) { $0 + $1.filter { $0 != .zero }.count }
    }

    public func limited(_ drives: [[Complex]]) -> [[Complex]] {
        guard let gain else { return drives }
        // An entry an element cannot play is not part of the drive.
        var g = drives
        for t in g.indices { for e in g[t].indices where gain[t][e] == .zero { g[t][e] = .zero } }
        guard let cap = amplitudeCap else { return g }
        for _ in 0..<3 {
            var sum = 0.0, count = 0
            for t in g.indices { for e in g[t].indices where gain[t][e] != .zero { sum += g[t][e].magnitudeSquared; count += 1 } }
            let lim = cap * (sum / Double(max(1, count))).squareRoot()
            for t in g.indices { for e in g[t].indices {
                let m = g[t][e].magnitude
                if m > lim { g[t][e] = g[t][e] * (lim / m) }
            } }
        }
        return g
    }

    public func potential(_ drives: [[Complex]], particle: ParticleMaterial) -> [Double] {
        var U = [Double](repeating: 0, count: lattice.count)
        for t in 0..<toneCount {
            let (k1, k2) = ForceCompiler.coefficients(particle: particle, medium: medium, frequency: frequencies[t])
            let S = try! fields(drives[t], tone: t, points: latticePoints)
            for n in 0..<lattice.count {
                let b = n * 4
                U[n] += k1 * S[b].magnitudeSquared
                    - k2 * (S[b + 1].magnitudeSquared + S[b + 2].magnitudeSquared + S[b + 3].magnitudeSquared)
            }
        }
        return U
    }

    public func adjoint(_ drives: [[Complex]], weights: [Double], particle: ParticleMaterial) -> [[Complex]] {
        let active = weights.indices.filter { weights[$0] != 0 }
        guard !active.isEmpty else { return drives.map { $0.map { _ in Complex.zero } } }
        let pts = active.map { latticePoints[$0] }
        return (0..<toneCount).map { t in
            let (k1, k2) = ForceCompiler.coefficients(particle: particle, medium: medium, frequency: frequencies[t])
            let S = try! fields(drives[t], tone: t, points: pts)
            var A = [SIMD2<Float>](repeating: .zero, count: pts.count * 4)
            for (q, n) in active.enumerated() {
                let w = weights[n], b = q * 4
                let a0 = S[b] * (w * k1)
                A[b] = SIMD2(Float(a0.re), Float(a0.im))
                for c in 1...3 {
                    let ac = S[b + c] * (w * k2)
                    A[b + c] = SIMD2(Float(ac.re), Float(ac.im))
                }
            }
            let grad = try! adjointPass(A: A, points: pts, tone: t)
            guard let g = gain?[t] else { return grad }
            return grad.indices.map { grad[$0] * g[$0].conjugate }
        }
    }

    /// What every element receives when one tone's drive lights small rigid
    /// scatterers at `points` (Born, by reciprocity): monopole strength cM ×
    /// the incident p, dipole cD × the incident ∇p (cM = −k²a³/3, cD = −a³/2 for
    /// a rigid, immovable sphere of radius a):
    ///     r_e = Σ_m cM G_e(x_m) p(x_m) + cD ∇G_e(x_m)·∇p(x_m).
    /// One forward pass at the scatterers, one adjoint pass over them.
    public func scattered(by points: [Vec3], monopole cM: Double, dipole cD: Double,
                          drive: [Complex], tone t: Int) throws -> [Complex] {
        let pts = points.map { SIMD4(Float($0.x), Float($0.y), Float($0.z), 0) }
        let S = try fields(drive, tone: t, points: pts)
        var A = [SIMD2<Float>](repeating: .zero, count: pts.count * 4)
        for m in 0..<pts.count {
            let a0 = (S[m * 4] * cM).conjugate
            A[m * 4] = SIMD2(Float(a0.re), Float(a0.im))
            for c in 1...3 {
                let ac = (S[m * 4 + c] * cD).conjugate * -1.0
                A[m * 4 + c] = SIMD2(Float(ac.re), Float(ac.im))
            }
        }
        let r = try adjointPass(A: A, points: pts, tone: t).map { $0.conjugate }
        guard let g = gain?[t] else { return r }
        return r.indices.map { r[$0] * g[$0] }                 // an element hears through the same resonance
    }

    /// Σ over points of conj(G_e)·A per element (see `arrayAdjoint`).
    func adjointPass(A: [SIMD2<Float>], points: [SIMD4<Float>], tone t: Int) throws -> [Complex] {
        var grad = [Complex](repeating: .zero, count: channels)
        // The kernel skips an element whose gain at this tone is zero.
        let gp = driveBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: channels)
        for e in 0..<channels {
            let g = gain?[t][e] ?? .one
            gp[e] = SIMD2(Float(g.re), Float(g.im))
        }
        var start = 0
        while start < points.count {
            let n = min(ArrayFieldGPU.chunk, points.count - start)
            let pp = pointBuf.contents().bindMemory(to: SIMD4<Float>.self, capacity: n)
            for i in 0..<n { pp[i] = points[start + i] }
            let ap = aBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: n * 4)
            for i in 0..<(n * 4) { ap[i] = A[start * 4 + i] }
            var P = params(tone: t, points: n)
            try ctx.dispatchGroups("arrayAdjoint", groups: channels, threads: 256) { enc in
                enc.setBuffer(gradBuf, offset: 0, index: 0)
                enc.setBuffer(elementBuffer, offset: 0, index: 1)
                enc.setBuffer(aBuf, offset: 0, index: 2)
                enc.setBuffer(pointBuf, offset: 0, index: 3)
                enc.setBytes(&P, length: MemoryLayout<ArrParams>.stride, index: 4)
                enc.setBuffer(driveBuf, offset: 0, index: 5)
            }
            let h = gradBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: channels)
            for e in 0..<channels { grad[e] += Complex(Double(h[e].x), Double(h[e].y)) }
            start += n
        }
        return grad
    }
}

/// One element as the array kernels read it (`struct ElementPF` in the shader).
struct ElementPF {
    var position: SIMD4<Float>
    var normal: SIMD4<Float>
    var area: Float
    var equivalentRadius: Float
    var coupling: SIMD2<Float>
    var gateIndex: Int32
    var monopole: Int32
    var pad0: Int32 = 0
    var pad1: Int32 = 0
}
