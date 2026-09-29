import Foundation
import Metal
import FieldCore

/// GPU build of the gate-granular operator ("port fields") for any preset:
/// horn couplings, element weights, axial wall images and air absorption, the
/// same terms as `FieldCore.Propagator.init`, which stays the reference. Gate
/// G-GPU-FS holds the two together.
///
/// Why it exists: the field is linear in the drive, so each gate's field is
/// computed once and every drive after that is a weighted sum of six columns.
/// On the free-standing machine a λ/2 lattice is ~0.8 M points × ~17 k virtual
/// elements × 7 image paths ≈ 10¹¹ Green's-function terms: minutes on the CPU,
/// seconds here.
public enum PortFieldsGPU {

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

    struct PFParams {
        var pointCount: UInt32
        var elementCount: UInt32
        var gateCount: UInt32
        var order: Int32
        var k: Float
        var prefactorMag: Float
        var alpha: Float
        var capSeparation: Float
        var reflection: Float
        var pad0: Float = 0, pad1: Float = 0, pad2: Float = 0
    }

    /// Points per command buffer: keeps any single GPU submission short, so a
    /// big lattice never trips the interactivity watchdog.
    static let chunk = 65_536

    /// Row-major (point, gate) operator at arbitrary points.
    public static func build(ctx: MetalContext, elements: [Element],
                             coupling: [Complex]? = nil, weights: [Double]? = nil,
                             walls: Propagator.Walls = .none, points: [Vec3],
                             frequency: Double, medium: Medium,
                             gateCount: Int) throws -> [Complex] {
        precondition(gateCount <= 64, "the kernel accumulates at most 64 gates per point")
        return try run("buildPortFields", outputsPerGate: 1, ctx: ctx, elements: elements,
                       coupling: coupling, weights: weights, walls: walls, points: points,
                       frequency: frequency, medium: medium, gateCount: gateCount)
    }

    /// Pressure rows and their analytic gradients: layout
    /// [(point · gates + gate) · 4 + c], c = 0 → p, 1…3 → ∂p/∂x, ∂p/∂y, ∂p/∂z.
    /// Mirrors `Propagator.gateGradientRows`.
    public static func buildWithGradient(ctx: MetalContext, elements: [Element],
                                         coupling: [Complex]? = nil, weights: [Double]? = nil,
                                         walls: Propagator.Walls = .none, points: [Vec3],
                                         frequency: Double, medium: Medium,
                                         gateCount: Int) throws -> [Complex] {
        precondition(gateCount <= 16, "the gradient kernel accumulates at most 16 gates per point")
        return try run("buildPortFieldsGrad", outputsPerGate: 4, ctx: ctx, elements: elements,
                       coupling: coupling, weights: weights, walls: walls, points: points,
                       frequency: frequency, medium: medium, gateCount: gateCount)
    }

    static func run(_ kernel: String, outputsPerGate: Int, ctx: MetalContext, elements: [Element],
                    coupling: [Complex]?, weights: [Double]?, walls: Propagator.Walls,
                    points: [Vec3], frequency: Double, medium: Medium,
                    gateCount: Int) throws -> [Complex] {
        let els: [ElementPF] = elements.enumerated().map { i, e in
            let w = weights?[i] ?? 1
            let c = (coupling?[i] ?? .one) * w
            return ElementPF(
                position: SIMD4(Float(e.position.x), Float(e.position.y), Float(e.position.z), 0),
                normal: SIMD4(Float(e.normal.x), Float(e.normal.y), Float(e.normal.z), 0),
                area: Float(e.area), equivalentRadius: Float(e.equivalentRadius),
                coupling: SIMD2(Float(c.re), Float(c.im)),
                gateIndex: Int32(w == 0 ? -1 : e.gateIndex),
                monopole: e.directivity == .monopole ? 1 : 0)
        }
        let k = medium.wavenumber(at: frequency)
        let dev = ctx.device
        guard let eb = dev.makeBuffer(bytes: els, length: max(1, els.count) * MemoryLayout<ElementPF>.stride,
                                      options: .storageModeShared) else { throw MetalContext.Error.noDevice }
        let per = gateCount * outputsPerGate
        var out = [Complex](repeating: .zero, count: points.count * per)
        var start = 0
        while start < points.count {
            let n = min(chunk, points.count - start)
            let pts = (start..<(start + n)).map {
                SIMD4<Float>(Float(points[$0].x), Float(points[$0].y), Float(points[$0].z), 0)
            }
            var params = PFParams(
                pointCount: UInt32(n), elementCount: UInt32(els.count),
                gateCount: UInt32(gateCount),
                order: Int32(walls.capSeparation > 0 ? walls.order : 0),
                k: Float(k),
                prefactorMag: Float(medium.density * medium.soundSpeed * k / (2 * .pi)),
                alpha: Float(medium.absorption(at: frequency)),
                capSeparation: Float(walls.capSeparation),
                reflection: Float(walls.reflectionCoefficient))
            guard let pb = dev.makeBuffer(bytes: pts, length: n * MemoryLayout<SIMD4<Float>>.stride,
                                          options: .storageModeShared),
                  let hb = dev.makeBuffer(length: n * per * MemoryLayout<SIMD2<Float>>.stride,
                                          options: .storageModeShared) else {
                throw MetalContext.Error.noDevice
            }
            try ctx.dispatch(kernel, count: n) { enc in
                enc.setBuffer(hb, offset: 0, index: 0)
                enc.setBuffer(eb, offset: 0, index: 1)
                enc.setBuffer(pb, offset: 0, index: 2)
                enc.setBytes(&params, length: MemoryLayout<PFParams>.stride, index: 3)
            }
            let h = hb.contents().bindMemory(to: SIMD2<Float>.self, capacity: n * per)
            for i in 0..<(n * per) {
                out[start * per + i] = Complex(Double(h[i].x), Double(h[i].y))
            }
            start += n
        }
        return out
    }

    /// A `Propagator` whose cached operator was built here. Everything
    /// downstream (inverse solver, Gor'kov, particles) works unchanged; the
    /// point evaluators still walk the elements on the CPU.
    public static func propagator(ctx: MetalContext, elements: [Element],
                                  coupling: [Complex]? = nil, weights: [Double]? = nil,
                                  walls: Propagator.Walls = .none, lattice: FieldLattice,
                                  frequency: Double, medium: Medium,
                                  gateCount: Int) throws -> Propagator {
        let H = try build(ctx: ctx, elements: elements, coupling: coupling, weights: weights,
                          walls: walls, points: lattice.positions, frequency: frequency,
                          medium: medium, gateCount: gateCount)
        return Propagator(elements: elements, lattice: lattice, frequency: frequency,
                          medium: medium, gateCount: gateCount, elementWeights: weights,
                          elementCoupling: coupling, walls: walls, precomputedH: H)
    }
}
