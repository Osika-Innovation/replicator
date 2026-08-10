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

        var skip = Set<String>(["--out", outDir])
        let wanted = args.dropFirst().first {
            !$0.hasPrefix("--") && !skip.contains($0)
        }

        let ctx = try? MetalContext()
        if ctx == nil { print("  (no Metal device — viewport panes will be blank)") }

        var made: [(String, Theme, CGImage)] = []
        for (tname, theme) in themes {
            for scene in SceneRegistry.all {
                if let w = wanted, !all, scene.id != w { continue }
                var st = scene.make(theme)
                if let ctx {
                    do {
                        let r = try Renderer(ctx: ctx)
                        r.load(SceneBuilder.rh1(palette: theme.isDark
                                                ? SceneBuilder.Palette()
                                                : SceneBuilder.Palette.light))
                        r.background = theme.viewportBackground
                        switch scene.camera {
                        case "front": r.camera = .front
                        case "top":   r.camera = .top
                        default:      r.camera = .home
                        }
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
