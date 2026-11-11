import Foundation
import CoreGraphics
import FieldCore
import FieldGPU

/// `fieldc shot` as a real function rather than top-level switch-case code.
///
/// Top-level `var`s inside a `switch case` in main.swift become lazily-initialized
/// globals and did not behave as written; moving the command into a function is
/// both the fix and what the "main.swift is a thin dispatcher" rule wanted.
public enum ShotCommand {

    @MainActor
    public static func run(args: [String]) -> Int32 {
        var outDir = "shots"
        if let i = args.firstIndex(of: "--out"), i + 1 < args.count { outDir = args[i + 1] }
        let dir = URL(fileURLWithPath: outDir)

        let all = args.contains("--all")
        var themes: [(String, Theme)] = [("dark", Theme.dark)]
        if args.contains("--light") { themes = [("light", Theme.light)] }
        if all { themes = [("dark", Theme.dark), ("light", Theme.light)] }

        // --compare: render every scene and compare it with its golden
        // (the committed set in shots/, or --golden DIR) instead of writing
        // it. Failures go to .build/snapshot-failures/ as <scene>.actual.png
        // and a red-highlighted <scene>.diff.png. Goldens are only ever
        // rewritten by an explicit `shot --all` (§21: never automatic).
        let comparing = args.contains("--compare")
        var goldenDir = "shots"
        if let i = args.firstIndex(of: "--golden"), i + 1 < args.count { goldenDir = args[i + 1] }
        var maxChanged = 0.005
        if let i = args.firstIndex(of: "--max-changed"), i + 1 < args.count, let v = Double(args[i + 1]) { maxChanged = v }
        let failDir = URL(fileURLWithPath: ".build/snapshot-failures")
        var compared = 0, failed: [String] = []
        let skip = Set<String>(["--out", outDir, "--golden", goldenDir, "--max-changed", String(maxChanged)])
        let wanted = args.dropFirst().first {
            !$0.hasPrefix("--") && !skip.contains($0)
        }

        let ctx = try? MetalContext()
        if ctx == nil { print("  (no Metal device — viewport panes will be blank)") }

        var made: [(String, Theme, CGImage)] = []
        for (tname, theme) in themes {
            for scene in SceneRegistry.all {
                if let w = wanted, !all, !comparing, scene.id != w { continue }
                if let w = wanted, comparing, scene.id != w { continue }
                var st = scene.make(theme)
                if let ctx, let preset = scene.solid {
                    do {
                        let r = try SolidRenderer(ctx: ctx)
                        let m = st.overlays.contains("cad.door")
                            ? RH1Model(design: MachineCAD.design(doorOpen: true)) : MachineCAD.model
                        let b = MachineCAD.batches(m, overlays: st.overlays)
                        r.load(opaque: b.opaque, transparent: b.transparent,
                               floor: SolidScene.floor(color: MachineCAD.floorColor(theme)))
                        st.viewport = try r.render(
                            MachineCAD.view(preset: preset, overlays: st.overlays, theme: theme),
                            width: 1480, height: 1000)
                    } catch {
                        print("  solid viewport failed for \(scene.id): \(error)")
                    }
                } else if let ctx {
                    do {
                        let r = try Renderer(ctx: ctx)
                        // The chamber with the element faces, the mold volume,
                        // and the object if the scene has one; the camera on
                        // the mold volume, as the live viewport opens.
                        let palette = theme.isDark ? SceneBuilder.Palette() : SceneBuilder.Palette.light
                        let c = PlateArray.rh1().centre
                        let half = Vec3(12e-3, 12e-3, 12e-3)
                        var extra = SceneBuilder.box(min: c - half, max: c + half,
                                                     color: SIMD4<Float>(0.5, 0.6, 0.7, 0.35))
                        if !st.objects.isEmpty && st.overlays.contains("solid") {
                            let ring = Mesh(triangles: STL.sampleRing().triangles.map {
                                Triangle($0.a + c, $0.b + c, $0.c + c) })
                            let g = SceneBuilder.object(ring, palette: palette)
                            extra.linePositions += g.linePositions; extra.lineColors += g.lineColors
                            extra.trianglePositions += g.trianglePositions; extra.triangleColors += g.triangleColors
                        }
                        r.load(SceneBuilder.rh1(palette: palette, design: RH1Design()), object: extra)
                        r.background = theme.viewportBackground
                        switch scene.camera {
                        case "front": r.camera = .front
                        case "top":   r.camera = .top
                        default:      r.camera = .home
                        }
                        r.camera.target = SIMD3<Float>(Float(c.x), Float(c.y), Float(c.z))
                        r.camera.distance = 0.085
                        st.viewport = try r.renderOffscreen(width: 1480, height: 1000)
                    } catch {
                        print("  viewport failed for \(scene.id): \(error)")
                    }
                }
                guard let img = Screenshot.render(st, width: 1280, height: 800) else {
                    print("  UI render failed: \(scene.id)")
                    continue
                }
                let name = "\(scene.id).\(tname).png"
                if comparing {
                    compared += 1
                    let label = name.padding(toLength: 30, withPad: " ", startingAt: 0)
                    guard let golden = Screenshot.loadPNG(URL(fileURLWithPath: goldenDir).appendingPathComponent(name)) else {
                        print("  \(label)NO GOLDEN in \(goldenDir)/"); failed.append(name); continue
                    }
                    let c = Screenshot.compare(img, golden: golden)
                    if c.passes(maxChanged: maxChanged) {
                        print(String(format: "  %@ok      %.4f %% of pixels changed (max Δ %d)", label as NSString, c.changedFraction * 100, c.maxDelta))
                    } else {
                        failed.append(name)
                        let base = "\(scene.id).\(tname)"
                        try? Screenshot.writePNG(img, to: failDir.appendingPathComponent(base + ".actual.png"))
                        if let d = c.diff { try? Screenshot.writePNG(d, to: failDir.appendingPathComponent(base + ".diff.png")) }
                        print(c.sizeMatches
                              ? String(format: "  %@CHANGED %.3f %% of pixels (max Δ %d) → %@/%@.diff.png", label as NSString,
                                       c.changedFraction * 100, c.maxDelta, failDir.path as NSString, base as NSString)
                              : "  \(label)SIZE differs from the golden (\(img.width)×\(img.height) vs \(golden.width)×\(golden.height))")
                    }
                    made.append((scene.id, theme, img))
                    continue
                }
                do {
                    try Screenshot.writePNG(img, to: dir.appendingPathComponent(name))
                    print("  \(name.padding(toLength: 30, withPad: " ", startingAt: 0))"
                        + scene.description)
                    made.append((scene.id, theme, img))
                } catch {
                    print("  write failed \(name): \(error)")
                }
            }
        }

        if comparing {
            print("\(compared - failed.count)/\(compared) scenes match their goldens in \(goldenDir)/"
                + (failed.isEmpty ? "" : "; changed: " + failed.joined(separator: ", ")))
            return failed.isEmpty && compared > 0 ? 0 : 1
        }
        if all || args.contains("--contact-sheet") {
            for (tname, theme) in themes {
                let subset = made.filter { $0.1.isDark == theme.isDark }.map { ($0.0, $0.2) }
                guard !subset.isEmpty else { continue }
                do {
                    if let sheet = try Screenshot.contactSheet(images: subset, theme: theme) {
                        let u = dir.appendingPathComponent("contact-sheet.\(tname).png")
                        try Screenshot.writePNG(sheet, to: u)
                        print("contact sheet: \(u.path)")
                    }
                } catch { print("contact sheet failed: \(error)") }
            }
        }
        print("\(made.count) screenshots -> \(dir.path)")
        return made.isEmpty ? 1 : 0
    }
}
