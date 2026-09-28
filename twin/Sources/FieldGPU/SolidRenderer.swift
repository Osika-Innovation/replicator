import Foundation
import Metal
import simd
import CoreGraphics
import FieldCore

/// De-indexed, GPU-ready triangles with per-corner normals and materials.
public struct SolidGeometry {
    public var positions: [SIMD3<Float>] = []
    public var normals: [SIMD3<Float>] = []
    public var colors: [SIMD4<Float>] = []
    public var materials: [SIMD4<Float>] = []
    public init() {}
    public var count: Int { positions.count }

    /// Append a millimetre mesh, converting to metres (the GPU frame).
    public mutating func append(_ mesh: IndexedMesh, color: SIMD4<Float>,
                                material: SIMD4<Float>, crease: Double = 38) {
        let (p, n) = mesh.shadingCorners(creaseDeg: crease)
        positions.reserveCapacity(positions.count + p.count)
        for i in p.indices {
            positions.append(SIMD3<Float>(Float(p[i].x * 0.001), Float(p[i].y * 0.001),
                                          Float(p[i].z * 0.001)))
            normals.append(SIMD3<Float>(Float(n[i].x), Float(n[i].y), Float(n[i].z)))
        }
        colors.append(contentsOf: repeatElement(color, count: p.count))
        materials.append(contentsOf: repeatElement(material, count: p.count))
    }
}

/// The RH-1 model as render batches.
public enum SolidScene {

    public static func color(_ m: CADMaterial) -> SIMD4<Float> {
        let (r, g, b, a) = m.rgba
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    public static func material(_ m: CADMaterial) -> SIMD4<Float> {
        SIMD4<Float>(Float(m.specular), Float(m.shininess), Float(m.emission),
                     m.isTransparent ? 1 : 0)
    }

    /// - Parameters:
    ///   - include: keep a part (default: everything).
    ///   - tint: override a part's colour (selection, assembly highlight).
    public static func build(_ model: RH1Model,
                             include: (CADPart) -> Bool = { _ in true },
                             tint: (CADPart) -> SIMD4<Float>? = { _ in nil })
        -> (opaque: SolidGeometry, transparent: SolidGeometry) {
        var o = SolidGeometry(), t = SolidGeometry()
        for p in model.parts where include(p) {
            let c = tint(p) ?? color(p.material)
            // Plates and machined parts keep crisp edges; curved shells smooth.
            let crease = p.material == .plateMetal ? 30.0 : 40.0
            if p.material.isTransparent && c.w < 0.99 {
                t.append(p.mesh, color: c, material: material(p.material), crease: crease)
            } else {
                var m = material(p.material)
                m.w = 0
                o.append(p.mesh, color: SIMD4<Float>(c.x, c.y, c.z, 1), material: m,
                         crease: crease)
            }
        }
        return (o, t)
    }

    /// A studio floor disc (flags = 2 → radial fade + contact shadow).
    public static func floor(radius: Double = 1.7, color c: SIMD4<Float>) -> SolidGeometry {
        var g = SolidGeometry()
        let m = Solid.tube(r0: 0, r1: radius * 1000, z0: -2, z1: 0, segments: 96)
        g.append(m, color: c, material: SIMD4<Float>(0, 1, 0, 2))
        return g
    }
}

/// What the solid view shows: camera, section cut, lights.
public struct SolidView {
    public var camera = OrbitCamera()
    public var background = SIMD4<Double>(0.055, 0.06, 0.072, 1)
    public var cut = false
    /// Azimuth wedge removed by the cut, degrees (machine frame, front = +x).
    public var cutFromDeg = -90.0
    public var cutToDeg = 0.0
    /// Optional height band for the cut, metres (0/0 = full height).
    public var cutZMin = 0.0
    public var cutZMax = 0.0
    public var hatch = 0.008
    public var capTint = SIMD4<Float>(0.80, 0.80, 0.82, 0.30)
    public var ambTop = SIMD4<Float>(0.42, 0.43, 0.46, 1)
    public var ambBottom = SIMD4<Float>(0.16, 0.15, 0.15, 1)
    public init() {}

    /// Whole-machine camera presets (machine frame, metres).
    public static func machine(_ name: String) -> SolidView {
        var v = SolidView()
        var c = OrbitCamera()
        c.target = SIMD3<Float>(0, 0, 0.84)
        c.fov = 0.52
        switch name {
        case "front":
            c.azimuth = 0; c.elevation = 0.06; c.distance = 3.55
        case "top":
            c.azimuth = -0.9; c.elevation = 1.35; c.distance = 2.4
            c.target = SIMD3<Float>(0, 0, 1.2)
        case "section":
            // Half section seen square-on: the cut plane is y = 0.
            c.azimuth = -.pi / 2; c.elevation = 0.04; c.distance = 3.55
            v.cut = true; v.cutFromDeg = -180; v.cutToDeg = 0
        case "section-iso":
            c.azimuth = -0.78; c.elevation = 0.26; c.distance = 3.6
            v.cut = true; v.cutFromDeg = -90; v.cutToDeg = 0
        case "detail":
            // The middle stack and the build-chamber floor, quarter-cut.
            c.target = SIMD3<Float>(0, 0, 1.0)
            c.azimuth = -0.72; c.elevation = 0.30; c.distance = 1.05
            v.cut = true; v.cutFromDeg = -90; v.cutToDeg = 0
        case "plate":
            // Looking down onto the mid-up face through the open top.
            c.target = SIMD3<Float>(0, 0, 1.06)
            c.azimuth = -0.9; c.elevation = 1.12; c.distance = 0.78
            v.cut = true; v.cutFromDeg = -180; v.cutToDeg = 180
            v.cutZMin = 1.0605; v.cutZMax = 1.70
        case "storage":
            c.target = SIMD3<Float>(0, 0, 0.66)
            c.azimuth = -0.8; c.elevation = 0.22; c.distance = 1.55
            v.cut = true; v.cutFromDeg = -90; v.cutToDeg = 0
        default: // iso
            c.azimuth = -0.62; c.elevation = 0.24; c.distance = 3.55
        }
        v.camera = c
        return v
    }
}

/// Renders `SolidGeometry` with the solid pipeline. Opaque pass (depth
/// write), then glass (depth test, no write), 4× MSAA, resolved to a shared
/// texture and read back once — the same pattern as the existing viewport
/// harness, so a CAD screenshot is what the live Machine view draws.
public final class SolidRenderer {
    public let ctx: MetalContext
    let sampleCount: Int
    var opaquePSO: MTLRenderPipelineState!
    var blendPSO: MTLRenderPipelineState!
    var depthWrite: MTLDepthStencilState!
    var depthRead: MTLDepthStencilState!
    struct Batch { var pos, nor, col, mat: MTLBuffer; var count: Int }
    var opaque: Batch?
    var transparent: Batch?
    var floorBatch: Batch?

    public init(ctx: MetalContext, pixelFormat: MTLPixelFormat = .bgra8Unorm,
                sampleCount: Int = 4) throws {
        self.ctx = ctx
        self.sampleCount = sampleCount
        guard let vf = ctx.library.makeFunction(name: "solidVertex"),
              let ff = ctx.library.makeFunction(name: "solidFragment") else {
            throw MetalContext.Error.missingFunction("solidVertex/solidFragment")
        }
        func pso(blend: Bool) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = vf; d.fragmentFunction = ff
            d.rasterSampleCount = sampleCount
            d.colorAttachments[0].pixelFormat = pixelFormat
            d.depthAttachmentPixelFormat = .depth32Float
            if blend {
                d.colorAttachments[0].isBlendingEnabled = true
                d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                d.colorAttachments[0].sourceAlphaBlendFactor = .one
                d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try ctx.device.makeRenderPipelineState(descriptor: d)
        }
        opaquePSO = try pso(blend: false)
        blendPSO = try pso(blend: true)
        let w = MTLDepthStencilDescriptor()
        w.depthCompareFunction = .lessEqual; w.isDepthWriteEnabled = true
        depthWrite = ctx.device.makeDepthStencilState(descriptor: w)
        let r = MTLDepthStencilDescriptor()
        r.depthCompareFunction = .lessEqual; r.isDepthWriteEnabled = false
        depthRead = ctx.device.makeDepthStencilState(descriptor: r)
    }

    func upload(_ g: SolidGeometry) -> Batch? {
        guard g.count > 0 else { return nil }
        let dev = ctx.device
        guard let p = dev.makeBuffer(bytes: g.positions, length: MemoryLayout<SIMD3<Float>>.stride * g.count, options: .storageModeShared),
              let n = dev.makeBuffer(bytes: g.normals, length: MemoryLayout<SIMD3<Float>>.stride * g.count, options: .storageModeShared),
              let c = dev.makeBuffer(bytes: g.colors, length: MemoryLayout<SIMD4<Float>>.stride * g.count, options: .storageModeShared),
              let m = dev.makeBuffer(bytes: g.materials, length: MemoryLayout<SIMD4<Float>>.stride * g.count, options: .storageModeShared)
        else { return nil }
        return Batch(pos: p, nor: n, col: c, mat: m, count: g.count)
    }

    public func load(opaque o: SolidGeometry, transparent t: SolidGeometry,
                     floor f: SolidGeometry? = nil) {
        opaque = upload(o)
        transparent = upload(t)
        floorBatch = f.flatMap { upload($0) }
    }

    struct Uniforms {
        var mvp: float4x4
        var eye: SIMD4<Float>
        var keyDir: SIMD4<Float>
        var fillDir: SIMD4<Float>
        var cut: SIMD4<Float>
        var cutAxis: SIMD4<Float>
        var ambTop: SIMD4<Float>
        var ambBottom: SIMD4<Float>
        var capTint: SIMD4<Float>
    }

    func uniforms(_ v: SolidView, aspect: Float) -> Uniforms {
        let c = v.camera
        let az = c.azimuth
        let key = normalize(SIMD3<Float>(cos(az + 0.75), sin(az + 0.75), 1.25))
        let fill = normalize(SIMD3<Float>(cos(az - 1.9), sin(az - 1.9), 0.25))
        let a0 = Float(v.cutFromDeg * .pi / 180), a1 = Float(v.cutToDeg * .pi / 180)
        return Uniforms(
            mvp: c.matrix(aspect: aspect),
            eye: SIMD4<Float>(c.eye, 1),
            keyDir: SIMD4<Float>(key, 0), fillDir: SIMD4<Float>(fill, 0),
            cut: SIMD4<Float>(v.cut ? 1 : 0, a0, a1, Float(v.cutZMax)),
            cutAxis: SIMD4<Float>(0, 0, Float(v.cutZMin), Float(v.hatch)),
            ambTop: v.ambTop, ambBottom: v.ambBottom, capTint: v.capTint)
    }

    public func encode(into enc: MTLRenderCommandEncoder, view v: SolidView, aspect: Float) {
        var u = uniforms(v, aspect: aspect)
        enc.setCullMode(.none)
        enc.setFrontFacing(.counterClockwise)
        func draw(_ b: Batch?, pso: MTLRenderPipelineState, depth: MTLDepthStencilState) {
            guard let b else { return }
            enc.setRenderPipelineState(pso)
            enc.setDepthStencilState(depth)
            enc.setVertexBuffer(b.pos, offset: 0, index: 0)
            enc.setVertexBuffer(b.nor, offset: 0, index: 1)
            enc.setVertexBuffer(b.col, offset: 0, index: 2)
            enc.setVertexBuffer(b.mat, offset: 0, index: 3)
            enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 4)
            enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: b.count)
        }
        draw(opaque, pso: opaquePSO, depth: depthWrite)
        draw(floorBatch, pso: blendPSO, depth: depthRead)
        draw(transparent, pso: blendPSO, depth: depthRead)
    }

    /// Offscreen render → CGImage (MSAA resolved).
    public func render(_ v: SolidView, width: Int, height: Int) throws -> CGImage? {
        let dev = ctx.device
        let msd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                           width: width, height: height, mipmapped: false)
        msd.textureType = .type2DMultisample; msd.sampleCount = sampleCount
        msd.usage = .renderTarget; msd.storageMode = .private
        let rsd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                           width: width, height: height, mipmapped: false)
        rsd.usage = [.renderTarget, .shaderRead]; rsd.storageMode = .shared
        let dsd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                           width: width, height: height, mipmapped: false)
        dsd.textureType = .type2DMultisample; dsd.sampleCount = sampleCount
        dsd.usage = .renderTarget; dsd.storageMode = .private
        guard let ms = dev.makeTexture(descriptor: msd), let rs = dev.makeTexture(descriptor: rsd),
              let dt = dev.makeTexture(descriptor: dsd) else { return nil }
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = ms
        rp.colorAttachments[0].resolveTexture = rs
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].storeAction = .multisampleResolve
        let bg = v.background
        rp.colorAttachments[0].clearColor = MTLClearColor(red: bg.x, green: bg.y, blue: bg.z, alpha: bg.w)
        rp.depthAttachment.texture = dt
        rp.depthAttachment.loadAction = .clear
        rp.depthAttachment.storeAction = .dontCare
        rp.depthAttachment.clearDepth = 1
        guard let cb = ctx.queue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rp) else { return nil }
        encode(into: enc, view: v, aspect: Float(width) / Float(height))
        enc.endEncoding()
        cb.commit(); cb.waitUntilCompleted()
        let rowBytes = width * 4
        var raw = [UInt8](repeating: 0, count: rowBytes * height)
        raw.withUnsafeMutableBytes {
            rs.getBytes($0.baseAddress!, bytesPerRow: rowBytes,
                        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        for i in stride(from: 0, to: raw.count, by: 4) { raw.swapAt(i, i + 2) }
        guard let provider = CGDataProvider(data: Data(raw) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}
