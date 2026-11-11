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
        // The RH-1's two plates in room air — the machine every mode simulates.
        MachineCAD.applyRail(&state)
        state.statusLine = "ready — no object loaded"
        state.inspector = SceneRegistry.machineSections()

        let doc = Document(state: state)
        // The default object: a wire ring, read from an STL on disk like any
        // other (written once if it is not there), so the app opens on
        // something the machine is gated to scan and to mold.
        let samples = URL(fileURLWithPath: "Samples")
        try? FileManager.default.createDirectory(at: samples,
                                                 withIntermediateDirectories: true)
        let ringURL = samples.appendingPathComponent("ring.stl")
        if !FileManager.default.fileExists(atPath: ringURL.path) {
            // Written in millimetres, the STL convention.
            let mm = Mesh(triangles: STL.sampleRing().triangles.map {
                Triangle($0.a * 1000, $0.b * 1000, $0.c * 1000)
            })
            try? STL.writeBinary(mm, to: ringURL)
        }
        let args = ProcessInfo.processInfo.arguments
        let chosen = args.firstIndex(of: "--stl").flatMap { $0 + 1 < args.count ? URL(fileURLWithPath: args[$0 + 1]) : nil }
        doc.load(url: chosen ?? ringURL)
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
        // `--compile` / `--scan`: run that on the loaded object straight away.
        if args.contains("--scan") { doc.state.mode = .scan }
        if args.contains("--scan") || args.contains("--compile") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { doc.runPrimary() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
