import Foundation
import FieldCore
import FieldGPU
import ImageIO
import CoreGraphics

/// `fieldc cad render` — the RH-1 solid model through the Metal solid
/// pipeline, headless (no window server), same renderer as the Machine tab.
enum CADRender {
    static let views = ["iso", "front", "section", "section-iso", "detail", "plate", "storage", "top"]

    static func writePNG(_ img: CGImage, _ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, img, nil)
        return CGImageDestinationFinalize(dest)
    }

    static func run(_ args: [String]) -> Int32 {
        var size = (w: 1600, h: 1200)
        if let s = CADCommand.value(args, "--size") {
            let p = s.split(separator: "x").compactMap { Int($0) }
            if p.count == 2 { size = (p[0], p[1]) }
        }
        let light = args.contains("--light")
        let all = args.contains("--all")
        let wanted = args.first { views.contains($0) } ?? "iso"
        let t0 = Date()
        let model = RH1Model(design: CADCommand.design(args), detail: CADCommand.detail(args))
        let tBuild = Date().timeIntervalSince(t0)
        do {
            let ctx = try MetalContext()
            let r = try SolidRenderer(ctx: ctx)
            let batches = SolidScene.build(model)
            let floorCol = light ? SIMD4<Float>(0.90, 0.89, 0.86, 1) : SIMD4<Float>(0.11, 0.115, 0.13, 1)
            r.load(opaque: batches.opaque, transparent: batches.transparent,
                   floor: SolidScene.floor(color: floorCol))
            let list = all ? views : [wanted]
            var outDir = CADCommand.value(args, "--out") ?? "."
            if !all, let png = args.first(where: { $0.hasSuffix(".png") }) {
                outDir = ""
                var v = SolidView.machine(wanted)
                style(&v, light: light)
                guard let img = try r.render(v, width: size.w, height: size.h), writePNG(img, png)
                else { print("render failed"); return 1 }
                print("wrote \(png)  (\(size.w)x\(size.h), \(model.totalTriangles) triangles, model \(String(format: "%.2fs", tBuild)))")
                return 0
            }
            for name in list {
                var v = SolidView.machine(name)
                style(&v, light: light)
                let path = (outDir as NSString).appendingPathComponent(
                    "rh1_\(name)\(light ? ".light" : "").png")
                guard let img = try r.render(v, width: size.w, height: size.h), writePNG(img, path)
                else { print("render failed: \(name)"); return 1 }
                print("wrote \(path)")
            }
            return 0
        } catch {
            print("render unavailable: \(error)")
            return 2
        }
    }

    static func style(_ v: inout SolidView, light: Bool) {
        if light {
            v.background = SIMD4<Double>(0.965, 0.958, 0.94, 1)
            v.ambTop = SIMD4<Float>(0.62, 0.62, 0.64, 1)
            v.ambBottom = SIMD4<Float>(0.30, 0.29, 0.28, 1)
            v.capTint = SIMD4<Float>(0.86, 0.86, 0.88, 0.5)
        }
    }
}

/// `fieldc cad step` — B-rep STEP via CadQuery (OpenCascade), generated from
/// the same parameter file, with the volume cross-check as gate G-STEP.
/// The only Python in the loop, and deliberately outside the app: FieldCore
/// stays dependency-free, the STEP path is a tool that reads its output.
enum CADStep {
    static func packageRoot() -> URL {
        // .build/release/fieldc → package root; falls back to the CWD.
        if let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            var dir = exe.deletingLastPathComponent()
            for _ in 0..<6 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Tools/rh1_step.py").path) {
                    return dir
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func python() -> String? {
        var candidates: [String] = []
        if let p = ProcessInfo.processInfo.environment["FIELDC_PYTHON"] { candidates.append(p) }
        candidates += ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: c)
            p.arguments = ["-c", "import cadquery"]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            if (try? p.run()) != nil { p.waitUntilExit(); if p.terminationStatus == 0 { return c } }
        }
        return nil
    }

    static func run(_ args: [String]) -> Int32 {
        guard let py = python() else {
            print("no Python with CadQuery found (set FIELDC_PYTHON); `pip install cadquery`")
            return 2
        }
        let out = CADCommand.value(args, "--out") ?? "cad-out/rh1.step"
        let outURL = URL(fileURLWithPath: out)
        try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let params = outURL.deletingLastPathComponent().appendingPathComponent("rh1_params.json")
        let report = outURL.deletingLastPathComponent().appendingPathComponent("rh1_step_report.json")
        let model = RH1Model(design: CADCommand.design(args), detail: CADCommand.detail(args))
        do { try CADExport.writeParams(model, to: params) } catch {
            print("params failed: \(error)"); return 1
        }
        let script = packageRoot().appendingPathComponent("Tools/rh1_step.py").path
        print("STEP via CadQuery (\(py)) ...")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: py)
        var a = [script, params.path, outURL.path, "--report", report.path]
        if args.contains("--no-windings") { a.append("--no-windings") }
        p.arguments = a
        do { try p.run() } catch { print("could not run \(py): \(error)"); return 2 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
