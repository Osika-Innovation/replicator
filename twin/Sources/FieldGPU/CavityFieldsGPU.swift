import Foundation
import Metal
import FieldCore

/// GPU modal sum for the cylindrical cavity (`FieldCore.CylinderCavity`):
/// per point and gate, p — or (p, ∂p/∂x, ∂p/∂y, ∂p/∂z) — summed over the
/// cavity's modes. The CPU `CylinderCavity.rows` is the reference; gate
/// G-GPU-CYL holds the two together.
public enum CavityFieldsGPU {

    struct CavMode {
        var gamma: Float              // Re μ
        var m: Int32
        var kappa: SIMD2<Float>
        var a0: SIMD2<Float>
        var rl: SIMD2<Float>
        var r0: SIMD2<Float>
        var dz: SIMD2<Float>
        var lam: SIMD2<Float>         // λ = μ/Re μ (1 for a rigid wall)
        var lamPow: SIMD2<Float>      // λ^{|m|−1}
        var tfac: SIMD2<Float>        // (λ² − 1)/2
        var terms: Int32              // multiplication-theorem terms (0 = real argument)
        var pad: Int32 = 0
    }

    struct CavParams {
        var pointCount: UInt32
        var modeCount: UInt32
        var gateCount: UInt32
        var withGradient: UInt32
        var tableCount: UInt32
        var tableOrders: UInt32
        var tableDx: Float
        var length: Float
    }

    static let lock = NSLock()
    nonisolated(unsafe) static var tables: [ObjectIdentifier: MTLBuffer] = [:]

    /// The cavity's Bessel table as a float device buffer, built once per cavity.
    static func table(_ ctx: MetalContext, _ cav: CylinderCavity) throws -> MTLBuffer {
        lock.lock(); defer { lock.unlock() }
        if let b = tables[ObjectIdentifier(cav)] { return b }
        let f = cav.table.values.map { Float($0) }
        guard let b = ctx.device.makeBuffer(bytes: f, length: f.count * MemoryLayout<Float>.stride,
                                            options: .storageModeShared) else { throw MetalContext.Error.noDevice }
        tables[ObjectIdentifier(cav)] = b
        return b
    }

    static func f2(_ c: Complex) -> SIMD2<Float> { SIMD2(Float(c.re), Float(c.im)) }

    /// Layout [(point · gates + gate) · per + c], per = 4 with gradient, else 1.
    public static func build(ctx: MetalContext, cavity cav: CylinderCavity,
                             source s: CylinderCavity.Source, points: [Vec3],
                             withGradient: Bool) throws -> [Complex] {
        let G = s.gateCount, Q = s.modeCount
        precondition(G <= 16, "the cavity kernel accumulates at most 16 gates per point")
        let modes: [CavMode] = (0..<Q).map { q in
            let a0 = s.pre[q] * s.invDen[q]
            let lam = s.lambda.isEmpty ? Complex.one : s.lambda[q]
            return CavMode(gamma: Float(s.mu.isEmpty ? cav.modes[q].zero / cav.radius : s.mu[q].re),
                           m: Int32(cav.modes[q].m),
                           kappa: f2(s.kappa[q]), a0: f2(a0),
                           rl: f2(s.eKL[q] * s.reflectionUpper), r0: f2(s.eKL[q] * s.reflectionLower),
                           dz: f2(Complex(0, -s.omegaRho) * s.invDen[q]),
                           lam: f2(lam), lamPow: f2(s.lambdaPow.isEmpty ? .one : s.lambdaPow[q]),
                           tfac: f2((lam * lam - .one) * 0.5),
                           terms: Int32(s.terms.isEmpty ? 0 : s.terms[q]))
        }
        var W = [SIMD2<Float>](repeating: .zero, count: Q * G * 2)
        for q in 0..<Q {
            for g in 0..<G {
                W[q * G * 2 + g] = f2(s.lower[q * G + g])
                W[q * G * 2 + G + g] = f2(s.upper[q * G + g])
            }
        }
        let dev = ctx.device
        let tb = try table(ctx, cav)
        guard let mb = dev.makeBuffer(bytes: modes, length: max(1, Q) * MemoryLayout<CavMode>.stride,
                                      options: .storageModeShared),
              let wb = dev.makeBuffer(bytes: W, length: max(1, W.count) * MemoryLayout<SIMD2<Float>>.stride,
                                      options: .storageModeShared) else { throw MetalContext.Error.noDevice }
        let per = withGradient ? 4 : 1
        var out = [Complex](repeating: .zero, count: points.count * G * per)
        let chunk = 16_384
        var start = 0
        while start < points.count {
            let n = min(chunk, points.count - start)
            let pts = (start..<(start + n)).map {
                SIMD4<Float>(Float(points[$0].x), Float(points[$0].y), Float(points[$0].z), 0)
            }
            var params = CavParams(pointCount: UInt32(n), modeCount: UInt32(Q), gateCount: UInt32(G),
                                   withGradient: withGradient ? 1 : 0,
                                   tableCount: UInt32(cav.table.count),
                                   tableOrders: UInt32(cav.table.maxOrder + 2),
                                   tableDx: Float(cav.table.dx), length: Float(s.length))
            guard let pb = dev.makeBuffer(bytes: pts, length: n * MemoryLayout<SIMD4<Float>>.stride,
                                          options: .storageModeShared),
                  let hb = dev.makeBuffer(length: n * G * per * MemoryLayout<SIMD2<Float>>.stride,
                                          options: .storageModeShared) else { throw MetalContext.Error.noDevice }
            try ctx.dispatch("buildCavityFields", count: n) { enc in
                enc.setBuffer(hb, offset: 0, index: 0)
                enc.setBuffer(mb, offset: 0, index: 1)
                enc.setBuffer(wb, offset: 0, index: 2)
                enc.setBuffer(tb, offset: 0, index: 3)
                enc.setBuffer(pb, offset: 0, index: 4)
                enc.setBytes(&params, length: MemoryLayout<CavParams>.stride, index: 5)
            }
            let h = hb.contents().bindMemory(to: SIMD2<Float>.self, capacity: n * G * per)
            for i in 0..<(n * G * per) { out[start * G * per + i] = Complex(Double(h[i].x), Double(h[i].y)) }
            start += n
        }
        return out
    }

    /// A `Propagator` for the cavity whose lattice operator was built here.
    public static func propagator(ctx: MetalContext, cavity cav: CylinderCavity,
                                  elements: [Element], coupling: [Complex]?,
                                  lattice: FieldLattice, frequency: Double, medium: Medium,
                                  gateCount: Int, zMin: Double) throws -> Propagator {
        let s = cav.source(elements: elements, coupling: coupling, gateCount: gateCount,
                           frequency: frequency, medium: medium, zMin: zMin)
        let H = try build(ctx: ctx, cavity: cav, source: s, points: lattice.positions, withGradient: false)
        return Propagator(elements: elements, lattice: lattice, frequency: frequency, medium: medium,
                          gateCount: gateCount, elementCoupling: coupling, cavity: cav, cavitySource: s,
                          precomputedH: H)
    }
}
