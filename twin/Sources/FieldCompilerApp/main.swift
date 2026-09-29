import AppKit
import SwiftUI
import FieldCore
import FieldUI

// The windowed app. AppKit bootstrap rather than a SwiftUI `App` scene because
// this is a bare SwiftPM executable with no .app bundle — setting the
// activation policy explicitly is what makes a plain binary show a real window
// and appear in the Dock.

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var document: Document!

    func applicationDidFinishLaunching(_ note: Notification) {
        // Launched from Finder / `open`, the working directory is "/". Work
        // from the package root instead (found by walking up from the binary),
        // so Samples/, cad-out/ and Receipts/ land where the CLI puts them.
        if let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            var dir = exe.deletingLastPathComponent()
            for _ in 0..<8 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                    FileManager.default.changeCurrentDirectoryPath(dir.path)
                    break
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        var state = AppState()
        state.theme = ProcessInfo.processInfo.arguments.contains("--light")
            ? .light : .dark
        // `--machine` opens straight into the Machine tab (the RH-1 solid model).
        state.mode = ProcessInfo.processInfo.arguments.contains("--machine") ? .machine : .compile
        // The free-standing RH-1 in room air — the machine every mode simulates.
        let (preset, _, walls) = RH1Freestanding.standard()
        let bv = preset.buildVolume
        let air = preset.medium
        MachineCAD.applyRail(&state)
        let lam = air.wavelength(at: 40_000) * 1000
        state.wavelengthText = String(format: "λ %.3f mm · node %.3f mm", lam, lam / 2)
        state.statusLine = "ready — no object loaded"
        state.inspector = [
            .init(title: "Machine", rows: [
                ("preset", preset.displayName),
                ("gates", "\(preset.gateCount) acoustic (3 throat piezos × 2 faces)"),
                ("apertures", "\(preset.elements.count / RH1Freestanding.gatesPerFace) physical · \(preset.elements.count) virtual"),
                ("build volume", String(format: "Ø%.0f × %.0f", bv.radius * 2000, bv.height * 1000)),
                ("λ @ 40 kHz", String(format: "%.3f mm", air.wavelength(at: 40_000) * 1000)),
            ]),
            .init(title: "Carrier", rows: [
                ("band", String(format: "%.0f–%.0f kHz", preset.defaultBand.lowerBound / 1000,
                                preset.defaultBand.upperBound / 1000)),
                ("medium", String(format: "air %.0f °C %.0f %% RH, %.2f m/s",
                                  air.air?.temperatureC ?? 20, air.air?.humidity ?? 50, air.soundSpeed)),
                ("absorption", String(format: "%.2f dB/m @ 40 kHz", air.absorption(at: 40_000) * 8.686)),
                ("walls", String(format: "plates, %d image orders, R %.2f", walls.order, walls.reflectionCoefficient)),
                ("solver", "T0 port fields (GPU)"),
            ]),
            .init(title: "Gates", rows: [
                ("G1 voxelizer", "0.40% ✓"),
                ("G2 energy", "0.71% ✓"),
                ("G3 time of flight", "0.44% ✓"),
                ("G6 node spacing", "2.5e-5 ✓"),
                ("G7 Gor'kov", "3.6e-7 ✓"),
                ("G-GPU vs CPU", "3.8e-6 ✓"),
            ]),
        ]

        let doc = Document(state: state)
        // Default object so the viewport shows something with real structure the
        // moment the app opens, and so the sample is on disk to re-load.
        let samples = URL(fileURLWithPath: "Samples")
        try? FileManager.default.createDirectory(at: samples,
                                                 withIntermediateDirectories: true)
        let cupURL = samples.appendingPathComponent("cup.stl")
        let cup = STL.sampleCup()
        if !FileManager.default.fileExists(atPath: cupURL.path) {
            // Written in millimetres, the STL convention.
            let mm = Mesh(triangles: cup.triangles.map {
                Triangle($0.a * 1000, $0.b * 1000, $0.c * 1000)
            })
            try? STL.writeBinary(mm, to: cupURL)
        }
        doc.adopt(cup, name: "cup.stl (sample)")
        self.document = doc

        let content = NSHostingView(rootView: LiveAppShell(doc))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Field Compiler — RSW-1"
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(content)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
