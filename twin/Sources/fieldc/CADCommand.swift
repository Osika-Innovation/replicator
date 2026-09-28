import Foundation
import FieldCore

/// `fieldc cad …` — the RH-1 solid model: gates, exports, drawing, BOM.
/// Rendering and STEP live in `CADRenderStep.swift`; everything here is
/// FieldCore only, so it runs on any machine Swift runs on.
enum CADCommand {

    static func detail(_ args: [String]) -> RH1Model.Detail {
        if args.contains("--preview") { return .preview }
        if args.contains("--fine") { return .fine }
        return .standard
    }

    static func design(_ args: [String]) -> RH1Design {
        var d = RH1Design()
        if let i = args.firstIndex(of: "--door"), i + 1 < args.count {
            let v = args[i + 1]
            d.doorAngleDeg = v == "open" ? 180 : (v == "closed" ? 0 : Double(v) ?? 0)
        }
        return d
    }

    static func value(_ args: [String], _ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func build(_ args: [String]) -> (RH1Model, Double) {
        let t0 = Date()
        let m = RH1Model(design: design(args), detail: detail(args))
        return (m, Date().timeIntervalSince(t0))
    }

    static func run(_ argsIn: [String]) -> Int32 {
        let args = Array(argsIn.dropFirst())            // drop "cad"
        let sub = args.first ?? "info"
        switch sub {

        case "info":
            let (m, dt) = build(args)
            let d = m.design
            print(String(format: "RH-1 free-standing: %d parts, %d triangles (built in %.2fs)",
                         m.parts.count, m.totalTriangles, dt))
            print("envelope    : Ø\(Int(d.bodyDiameter)) × \(Int(d.overallHeight)) mm")
            for f in d.faces {
                print(String(format: "face %-9@: z %7.1f (back %7.1f), faces %@, torus %6.1f, %@",
                             f.id as NSString, f.faceZ, f.backZ, f.facing.rawValue, f.torusZ,
                             f.handedness))
            }
            print(String(format: "build chamber: %.0f × %.0f; storage chamber: %.0f × %.1f",
                         d.rearGlassOD, d.buildChamberHeight, d.storageLinerID,
                         d.storageChamberHeight))
            let p = m.pattern
            print("face pattern: \(p.sites.count) Vogel sites, \(p.drilled.count) drilled, "
                + "\(p.subsumedCount) inside slot voids; \(d.slotArms) slots "
                + String(format: "%.0f mm long", p.slotLength))
            print("\nprovenance:")
            for r in d.provenance {
                print("  [\(r.register.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0))] "
                    + "\(r.item): \(r.value)  — \(r.source)")
            }
            if args.contains("--reconciliation") {
                print("\nreconciliation:")
                for r in RH1Design.reconciliation {
                    print("  • \(r.topic)\n      papers: \(r.papers)\n      site:   \(r.site)"
                        + "\n      model:  \(r.model)\n      why:    \(r.why)")
                }
            }
            return 0

        case "check":
            let (m, dt) = build(args)
            print(String(format: "model: %d parts, %d triangles (%.2fs)", m.parts.count,
                         m.totalTriangles, dt))
            let t0 = Date()
            let gates = CADGates.runAll(m, interference: !args.contains("--no-interference")
                                        && m.detail != .preview)
            let r = Receipt(name: "cad", gates: gates,
                            durationSeconds: Date().timeIntervalSince(t0) + dt,
                            device: deviceName(), gitSHA: gitSHA())
            print(r.summary)
            if args.contains("--rules") {
                print("\ndesign rules:")
                for x in CADGates.designRules(m) {
                    print(String(format: "  %@ %-5@ %-44@ %8.3f mm (min %.2f)",
                                 (x.passed ? "✓" : "✗") as NSString, x.id as NSString,
                                 x.what as NSString, x.clearance, x.minimum))
                }
            }
            if args.contains("--receipt") { writeReceipt(r) }
            return r.allPassed ? 0 : 1

        case "bom":
            let (m, _) = build(args)
            let md = CADExport.bomMarkdown(m)
            if let out = value(args, "--out") {
                try? md.write(toFile: out, atomically: true, encoding: .utf8)
                print("wrote \(out)")
            } else { print(md) }
            if let js = value(args, "--json") {
                let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? enc.encode(CADExport.bom(m)) {
                    try? data.write(to: URL(fileURLWithPath: js)); print("wrote \(js)")
                }
            }
            return 0

        case "params":
            let (m, _) = build(args)
            let out = args.dropFirst().first { $0.hasSuffix(".json") } ?? "rh1_params.json"
            do { try CADExport.writeParams(m, to: URL(fileURLWithPath: out)); print("wrote \(out)") }
            catch { print("params failed: \(error)"); return 1 }
            return 0

        case "drawing":
            let (m, _) = build(args)
            let out = args.dropFirst().first { $0.hasSuffix(".svg") } ?? "rh1_general_arrangement.svg"
            do {
                try CADExport.drawingSVG(m).write(toFile: out, atomically: true, encoding: .utf8)
                print("wrote \(out)")
            } catch { print("drawing failed: \(error)"); return 1 }
            return 0

        case "export":
            let (m, dt) = build(args)
            let dir = URL(fileURLWithPath: value(args, "--out") ?? "cad-out")
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let n = try CADExport.writeSTL(m, to: dir.appendingPathComponent("stl"))
                print("  \(n) STL parts -> \(dir.path)/stl")
                try CADExport.writeOBJ(m, to: dir.appendingPathComponent("rh1.obj"))
                print("  rh1.obj + rh1.mtl (\(m.totalTriangles) triangles)")
                try CADExport.writeParams(m, to: dir.appendingPathComponent("rh1_params.json"))
                print("  rh1_params.json")
                try CADExport.bomMarkdown(m).write(to: dir.appendingPathComponent("BOM.md"),
                                                   atomically: true, encoding: .utf8)
                print("  BOM.md")
                try CADExport.drawingSVG(m).write(
                    to: dir.appendingPathComponent("rh1_general_arrangement.svg"),
                    atomically: true, encoding: .utf8)
                print("  rh1_general_arrangement.svg")
                print(String(format: "model built in %.2fs", dt))
            } catch { print("export failed: \(error)"); return 1 }
            return 0

        case "render":
            return CADRender.run(args)

        case "step":
            return CADStep.run(args)

        default:
            print("""
            fieldc cad — the RH-1 solid model

              fieldc cad info [--reconciliation]    parts, stack, provenance of every number
              fieldc cad check [--rules] [--receipt] CAD gates: watertight, volumes, clearances,
                                                    interference, dimension audit, parastichies
              fieldc cad render [iso|front|section|top|plate|detail] [--light] [--door open] [out.png]
              fieldc cad export [--out DIR]         STL per part, OBJ+MTL, params JSON, BOM, drawing
              fieldc cad drawing [out.svg]          general-arrangement drawing from the parameters
              fieldc cad bom [--out BOM.md] [--json bom.json]
              fieldc cad params [out.json]          the design + pattern, input to the STEP generator
              fieldc cad step [--out rh1.step]      B-rep STEP via CadQuery, volume-cross-checked
              options: --preview | --fine, --door open|closed|<deg>
            """)
            return sub == "help" ? 0 : 1
        }
    }
}
