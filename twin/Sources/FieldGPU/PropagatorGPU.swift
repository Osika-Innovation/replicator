import Foundation
import Metal
import FieldCore

/// GPU T0. Holds H resident on the device so the render pass can read it with
/// no CPU readback (§8 viewport ruling).
public final class PropagatorGPU {
    public let ctx: MetalContext
    public let lattice: FieldLattice
    public let gateCount: Int
    public let frequency: Double
    public let medium: Medium

    private let hBuffer: MTLBuffer          // float2 per (point, gate)
    private let elementBuffer: MTLBuffer
    private var paramsBuffer: MTLBuffer
    public private(set) var buildSeconds: Double = 0

    struct ElementGPU {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var area: Float
        var equivalentRadius: Float
        var gateIndex: Int32
        var _pad: Int32 = 0
    }

    struct PropParams {
        var origin: SIMD3<Float>
        var spacing: Float
        var nx: UInt32, ny: UInt32, nz: UInt32
        var elementCount: UInt32
        var gateCount: UInt32
        var k: Float
        var prefactorMag: Float
        var _pad: Float = 0
    }

    public init(ctx: MetalContext, elements: [Element], lattice: FieldLattice,
                frequency: Double, medium: Medium, gateCount: Int) throws {
        self.ctx = ctx
        self.lattice = lattice
        self.gateCount = gateCount
        self.frequency = frequency
        self.medium = medium

        var els = elements.map { e in
            ElementGPU(position: SIMD3<Float>(Float(e.position.x), Float(e.position.y),
                                              Float(e.position.z)),
                       normal: SIMD3<Float>(Float(e.normal.x), Float(e.normal.y),
                                            Float(e.normal.z)),
                       area: Float(e.area),
                       equivalentRadius: Float(e.equivalentRadius),
                       gateIndex: Int32(e.gateIndex))
        }
        guard let eb = ctx.device.makeBuffer(bytes: &els,
                                             length: MemoryLayout<ElementGPU>.stride * els.count,
                                             options: .storageModeShared) else {
            throw MetalContext.Error.noDevice
        }
        self.elementBuffer = eb

        let k = medium.wavenumber(at: frequency)
        var params = PropParams(
            origin: SIMD3<Float>(Float(lattice.origin.x), Float(lattice.origin.y),
                                 Float(lattice.origin.z)),
            spacing: Float(lattice.spacing),
            nx: UInt32(lattice.nx), ny: UInt32(lattice.ny), nz: UInt32(lattice.nz),
            elementCount: UInt32(elements.count), gateCount: UInt32(gateCount),
            k: Float(k),
            prefactorMag: Float(medium.density * medium.soundSpeed * k / (2 * .pi)))
        guard let pb = ctx.device.makeBuffer(bytes: &params,
                                             length: MemoryLayout<PropParams>.stride,
                                             options: .storageModeShared),
              let hb = ctx.device.makeBuffer(
                length: MemoryLayout<SIMD2<Float>>.stride * lattice.count * gateCount,
                options: .storageModePrivate) else {
            throw MetalContext.Error.noDevice
        }
        self.paramsBuffer = pb
        self.hBuffer = hb

        let t0 = Date()
        try ctx.dispatch("buildH", count: lattice.count) { enc in
            enc.setBuffer(hb, offset: 0, index: 0)
            enc.setBuffer(eb, offset: 0, index: 1)
            enc.setBuffer(pb, offset: 0, index: 2)
        }
        self.buildSeconds = Date().timeIntervalSince(t0)
    }

    /// p = H u. Returns a device buffer of float2, kept GPU-resident.
    public func forward(_ drive: [Complex]) throws -> MTLBuffer {
        precondition(drive.count == gateCount)
        var u = drive.map { SIMD2<Float>(Float($0.re), Float($0.im)) }
        guard let ub = ctx.device.makeBuffer(bytes: &u,
                                             length: MemoryLayout<SIMD2<Float>>.stride * u.count,
                                             options: .storageModeShared),
              let out = ctx.device.makeBuffer(
                length: MemoryLayout<SIMD2<Float>>.stride * lattice.count,
                options: .storageModeShared) else {
            throw MetalContext.Error.noDevice
        }
        try ctx.dispatch("forward", count: lattice.count) { enc in
            enc.setBuffer(hBuffer, offset: 0, index: 0)
            enc.setBuffer(ub, offset: 0, index: 1)
            enc.setBuffer(out, offset: 0, index: 2)
            enc.setBuffer(paramsBuffer, offset: 0, index: 3)
        }
        return out
    }

    /// Readback for validation only — the render path must never do this.
    public func forwardToHost(_ drive: [Complex]) throws -> [Complex] {
        let buf = try forward(drive)
        let p = buf.contents().bindMemory(to: SIMD2<Float>.self, capacity: lattice.count)
        return (0..<lattice.count).map { Complex(Double(p[$0].x), Double(p[$0].y)) }
    }
}
