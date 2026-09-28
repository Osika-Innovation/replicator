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
        let preset = RH1.preset()
        state.gateCount = preset.gateCount
        state.elementCount = preset.elements.count
        state.statusLine = "ready — no object loaded"
        state.inspector = [
            .init(title: "Machine", rows: [
                ("preset", "RH-1"),
                ("gates", "\(preset.gateCount) acoustic"),
                ("elements", "\(preset.elements.count)"),
                ("build volume", "Ø280 × 300"),
                ("λ @ 40 kHz", "8.575 mm"),
            ]),
            .init(title: "Carrier", rows: [
                ("band", "20–80 kHz"),
                ("medium", "air 343 m/s"),
                ("solver", "T0 propagator"),
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
