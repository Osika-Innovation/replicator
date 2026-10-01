import Foundation
import Metal

/// Shared Metal device, queue and shader library.
///
/// Shaders are compiled AT RUNTIME from `.metal` source shipped as package
/// resources (§8). The offline `metal` compiler requires Xcode, which is not
/// installed; `device.makeLibrary(source:)` uses the OS compiler service and
/// works without it. Two consequences, both good: no build-system coupling, and
/// kernels are hot-reloadable — edit a shader, call `reload()`, see the field
/// change without rebuilding the app.
public final class MetalContext {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public private(set) var library: MTLLibrary
    private var pipelines: [String: MTLComputePipelineState] = [:]
    private let shaderDirectory: URL?

    public enum Error: Swift.Error, CustomStringConvertible {
        case noDevice
        case noQueue
        case missingShaders(String)
        case compileFailed(String)
        case missingFunction(String)

        public var description: String {
            switch self {
            case .noDevice: return "no Metal device (is this a headless VM?)"
            case .noQueue: return "could not create a Metal command queue"
            case .missingShaders(let s): return "shader source not found: \(s)"
            case .compileFailed(let s): return "shader compile failed: \(s)"
            case .missingFunction(let s): return "no such kernel: \(s)"
            }
        }
    }

    public static func shaderSource(overrideDirectory: URL? = nil) throws -> (String, URL?) {
        let names = ["propagator", "array", "render", "solid"]
        // Prefer an override directory so `fieldc gate --shader-dir ./Shaders`
        // can gate an edited kernel without rebuilding (§23).
        var dir = overrideDirectory
        if dir == nil, let b = Bundle.module.resourceURL?.appendingPathComponent("Shaders") {
            dir = b
        }
        guard let d = dir else { throw Error.missingShaders("no shader directory") }
        var combined = ""
        for n in names {
            let url = d.appendingPathComponent("\(n).metal")
            guard let s = try? String(contentsOf: url, encoding: .utf8) else {
                throw Error.missingShaders(url.path)
            }
            combined += s + "\n"
        }
        return (combined, d)
    }

    public init(shaderDirectory: URL? = nil) throws {
        guard let dev = MTLCreateSystemDefaultDevice() else { throw Error.noDevice }
        guard let q = dev.makeCommandQueue() else { throw Error.noQueue }
        self.device = dev
        self.queue = q
        let (src, dir) = try MetalContext.shaderSource(overrideDirectory: shaderDirectory)
        self.shaderDirectory = dir
        do {
            self.library = try dev.makeLibrary(source: src, options: nil)
        } catch {
            throw Error.compileFailed("\(error)")
        }
    }

    /// Recompile from disk. The hot-reload path.
    public func reload() throws {
        let (src, _) = try MetalContext.shaderSource(overrideDirectory: shaderDirectory)
        library = try device.makeLibrary(source: src, options: nil)
        pipelines.removeAll()
    }

    public func pipeline(_ name: String) throws -> MTLComputePipelineState {
        if let p = pipelines[name] { return p }
        guard let fn = library.makeFunction(name: name) else {
            throw Error.missingFunction(name)
        }
        let p = try device.makeComputePipelineState(function: fn)
        pipelines[name] = p
        return p
    }

    public var deviceDescription: String {
        "\(device.name) (unified memory: \(device.hasUnifiedMemory), "
        + "max buffer: \(device.maxBufferLength / (1024 * 1024)) MB)"
    }

    /// Dispatch a kernel as `groups` threadgroups of `threads` threads each
    /// (for kernels that reduce inside a threadgroup).
    public func dispatchGroups(_ name: String, groups: Int, threads: Int,
                               _ configure: (MTLComputeCommandEncoder) -> Void) throws {
        guard groups > 0 else { return }
        let pso = try pipeline(name)
        guard let cb = queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(pso)
        configure(enc)
        enc.dispatchThreadgroups(MTLSize(width: groups, height: 1, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: threads, height: 1, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
    }

    /// Dispatch a 1-D compute kernel over `count` threads.
    public func dispatch(_ name: String, count: Int,
                         _ configure: (MTLComputeCommandEncoder) -> Void) throws {
        guard count > 0 else { return }
        let pso = try pipeline(name)
        guard let cb = queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(pso)
        configure(enc)
        let w = min(pso.maxTotalThreadsPerThreadgroup, 256)
        enc.dispatchThreads(MTLSize(width: count, height: 1, depth: 1),
                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
    }
}
