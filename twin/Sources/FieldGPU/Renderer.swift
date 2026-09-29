import Foundation
import Metal
import MetalKit
import simd
import CoreGraphics
import FieldCore

public struct OrbitCamera: Sendable {
    // Defaults frame the free-standing build chamber (Ø410 faces, 460 mm apart).
    public var target = SIMD3<Float>(0, 0, 0.21)
    public var distance: Float = 1.25
    public var azimuth: Float = -0.9        // radians
    public var elevation: Float = 0.32
    public var fov: Float = 0.62
    public var orthographic = false

    public init() {}

    public static let home = OrbitCamera()
    public static var front: OrbitCamera { var c = OrbitCamera(); c.azimuth = -.pi / 2; c.elevation = 0.05; c.distance = 1.15; return c }
    public static var top: OrbitCamera { var c = OrbitCamera(); c.elevation = 1.45; c.distance = 1.35; return c }
    public static var iso: OrbitCamera { OrbitCamera() }

    public var eye: SIMD3<Float> {
        SIMD3<Float>(target.x + distance * cos(elevation) * cos(azimuth),
                     target.y + distance * cos(elevation) * sin(azimuth),
                     target.z + distance * sin(elevation))
    }

    public func matrix(aspect: Float) -> float4x4 {
        let up = SIMD3<Float>(0, 0, 1)
        let f = normalize(target - eye)
        let s = normalize(cross(f, up))
        let u = cross(s, f)
        let view = float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)))
        let near: Float = 0.02, far: Float = 6.0
        let proj: float4x4
        if orthographic {
            let h = distance * 0.55, w = h * aspect
            proj = float4x4(columns: (
                SIMD4<Float>(1 / w, 0, 0, 0),
                SIMD4<Float>(0, 1 / h, 0, 0),
                SIMD4<Float>(0, 0, -2 / (far - near), 0),
                SIMD4<Float>(0, 0, -(far + near) / (far - near), 1)))
        } else {
            let y = 1 / tan(fov / 2)
            proj = float4x4(columns: (
                SIMD4<Float>(y / aspect, 0, 0, 0),
                SIMD4<Float>(0, y, 0, 0),
                SIMD4<Float>(0, 0, far / (near - far), -1),
                SIMD4<Float>(0, 0, (far * near) / (near - far), 0)))
        }
        return proj * view
    }
}

struct SceneUniforms {
    var mvp: float4x4
    var tint: SIMD4<Float>
    var pointSize: Float
    var pad0: Float = 0, pad1: Float = 0, pad2: Float = 0
}

/// Draws the machine, and (when present) a field slice from a GPU-resident
/// buffer. Same renderer for the on-screen view and for offscreen screenshots —
/// so a screenshot cannot diverge from what a user sees (§21).
public final class Renderer {
    public let ctx: MetalContext
    private var linePipeline: MTLRenderPipelineState!
    private var trianglePipeline: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!

    private var linePos: MTLBuffer?
    private var lineCol: MTLBuffer?
    private var lineCount = 0
    private var triPos: MTLBuffer?
    private var triCol: MTLBuffer?
    private var triCount = 0

    public var camera = OrbitCamera.home
    public var background = SIMD4<Double>(0.055, 0.06, 0.072, 1)

    public init(ctx: MetalContext, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        self.ctx = ctx
        let vfn = ctx.library.makeFunction(name: "sceneVertex")
        let ffn = ctx.library.makeFunction(name: "sceneFragment")
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        desc.depthAttachmentPixelFormat = .depth32Float
        linePipeline = try ctx.device.makeRenderPipelineState(descriptor: desc)
        trianglePipeline = try ctx.device.makeRenderPipelineState(descriptor: desc)

        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .lessEqual
        dd.isDepthWriteEnabled = true
        depthState = ctx.device.makeDepthStencilState(descriptor: dd)
    }

    /// Machine chrome plus an optional object, drawn in one pass.
    public func load(_ g: SceneGeometry, object: SceneGeometry? = nil) {
        var c = g
        if let o = object {
            c.linePositions += o.linePositions
            c.lineColors += o.lineColors
            c.trianglePositions += o.trianglePositions
            c.triangleColors += o.triangleColors
        }
        loadCombined(c)
    }

    private func loadCombined(_ g: SceneGeometry) {
        lineCount = g.linePositions.count
        triCount = g.trianglePositions.count
        if lineCount > 0 {
            linePos = ctx.device.makeBuffer(bytes: g.linePositions,
                length: MemoryLayout<SIMD3<Float>>.stride * lineCount, options: .storageModeShared)
            lineCol = ctx.device.makeBuffer(bytes: g.lineColors,
                length: MemoryLayout<SIMD4<Float>>.stride * lineCount, options: .storageModeShared)
        }
        if triCount > 0 {
            triPos = ctx.device.makeBuffer(bytes: g.trianglePositions,
                length: MemoryLayout<SIMD3<Float>>.stride * triCount, options: .storageModeShared)
            triCol = ctx.device.makeBuffer(bytes: g.triangleColors,
                length: MemoryLayout<SIMD4<Float>>.stride * triCount, options: .storageModeShared)
        }
    }

    public func encode(into enc: MTLRenderCommandEncoder, aspect: Float) {
        var u = SceneUniforms(mvp: camera.matrix(aspect: aspect),
                              tint: SIMD4<Float>(1, 1, 1, 1), pointSize: 2)
        enc.setDepthStencilState(depthState)
        if triCount > 0, let p = triPos, let c = triCol {
            enc.setRenderPipelineState(trianglePipeline)
            enc.setVertexBuffer(p, offset: 0, index: 0)
            enc.setVertexBuffer(c, offset: 0, index: 1)
            enc.setVertexBytes(&u, length: MemoryLayout<SceneUniforms>.stride, index: 2)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triCount)
        }
        if lineCount > 0, let p = linePos, let c = lineCol {
            enc.setRenderPipelineState(linePipeline)
            enc.setVertexBuffer(p, offset: 0, index: 0)
            enc.setVertexBuffer(c, offset: 0, index: 1)
            enc.setVertexBytes(&u, length: MemoryLayout<SceneUniforms>.stride, index: 2)
            enc.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineCount)
        }
    }

    /// Render to an offscreen texture and return a CGImage.
    /// This is the viewport half of the screenshot harness (§21): the SAME
    /// renderer, a different drawable.
    public func renderOffscreen(width: Int, height: Int) throws -> CGImage? {
        let td = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .shared
        guard let tex = ctx.device.makeTexture(descriptor: td) else { return nil }

        let dd = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        dd.usage = .renderTarget
        dd.storageMode = .private
        guard let depth = ctx.device.makeTexture(descriptor: dd) else { return nil }

        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = tex
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].storeAction = .store
        rp.colorAttachments[0].clearColor = MTLClearColor(
            red: background.x, green: background.y, blue: background.z, alpha: background.w)
        rp.depthAttachment.texture = depth
        rp.depthAttachment.loadAction = .clear
        rp.depthAttachment.storeAction = .dontCare
        rp.depthAttachment.clearDepth = 1.0

        guard let cb = ctx.queue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rp) else { return nil }
        encode(into: enc, aspect: Float(width) / Float(height))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()

        let rowBytes = width * 4
        var raw = [UInt8](repeating: 0, count: rowBytes * height)
        raw.withUnsafeMutableBytes { buf in
            tex.getBytes(buf.baseAddress!, bytesPerRow: rowBytes,
                         from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        // BGRA -> RGBA
        for i in stride(from: 0, to: raw.count, by: 4) {
            raw.swapAt(i, i + 2)
        }
        guard let provider = CGDataProvider(data: Data(raw) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: rowBytes,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
