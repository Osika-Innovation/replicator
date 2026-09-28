import SwiftUI
import AppKit
import MetalKit
import FieldCore
import FieldGPU

/// A live, interactive Metal viewport — the on-screen counterpart of the
/// offscreen path used by the screenshot harness. Same `Renderer`, different
/// drawable, which is what keeps a screenshot from diverging from what a user
/// sees (§21).
public final class ViewportMTKView: MTKView {
    private var renderer: Renderer?
    /// Machine tab: the RH-1 solid model, drawn instead of the build volume.
    private var solid: SolidRenderer?
    public var solidView = SolidView.machine("iso")
    public var showMachine = false
    private var lastDrag: NSPoint = .zero
    private var palette = FieldGPU.SceneBuilder.Palette()
    /// Set by the document model when an object is loaded or cleared.
    public var onLoadRequest: ((URL) -> Void)?

    /// Compose the whole scene: machine chrome, plus whichever overlay layers
    /// are switched on. One upload; no per-frame readback.
    public func setScene(object: Mesh?, fits: Bool,
                         fieldMagnitude: [Double]? = nil,
                         fieldLattice: FieldLattice? = nil,
                         traps: [(position: Vec3, depth: Double)] = [],
                         particles: ParticleSim? = nil,
                         boundary: (elements: [Element], drive: [Complex])? = nil,
                         chords: (gates: [Scan.Gate], list: [MatrixPencil.Chord])? = nil) {
        guard let r = renderer else { return }
        var extra = SceneGeometry()
        func merge(_ g: SceneGeometry) {
            extra.linePositions += g.linePositions
            extra.lineColors += g.lineColors
            extra.trianglePositions += g.trianglePositions
            extra.triangleColors += g.triangleColors
        }
        if let m = fieldMagnitude, let lat = fieldLattice {
            merge(FieldGPU.SceneBuilder.fieldSlice(magnitude: m, lattice: lat))
        }
        if !traps.isEmpty {
            merge(FieldGPU.SceneBuilder.traps(traps, palette: palette))
        }
        if let b = boundary {
            merge(FieldGPU.SceneBuilder.boundary(elements: b.elements,
                                                 drive: b.drive, palette: palette))
        }
        if let sim = particles {
            merge(FieldGPU.SceneBuilder.particles(sim))
        }
        if let c = chords {
            for (i, ch) in c.list.prefix(4).enumerated() {
                merge(FieldGPU.SceneBuilder.chords(gates: c.gates, chord: ch,
                                                   rank: i, palette: palette))
            }
        }
        if let mesh = object {
            merge(FieldGPU.SceneBuilder.object(mesh, palette: palette, fits: fits))
        }
        r.load(FieldGPU.SceneBuilder.rh1(palette: palette), object: extra)
    }

    public static func make(ctx: MetalContext,
                            palette: FieldGPU.SceneBuilder.Palette,
                            background: SIMD4<Double>) -> ViewportMTKView {
        let v = ViewportMTKView(frame: .zero, device: ctx.device)
        v.configure(ctx: ctx, palette: palette, background: background)
        return v
    }

    private func configure(ctx: MetalContext, palette: FieldGPU.SceneBuilder.Palette,
                           background: SIMD4<Double>) {
        self.colorPixelFormat = .bgra8Unorm
        self.depthStencilPixelFormat = .depth32Float
        self.clearColor = MTLClearColor(red: background.x, green: background.y,
                                        blue: background.z, alpha: background.w)
        self.enableSetNeedsDisplay = false
        self.isPaused = false
        self.preferredFramesPerSecond = 60
        self.palette = palette
        self.registerForDraggedTypes([.fileURL])
        if let r = try? Renderer(ctx: ctx, pixelFormat: .bgra8Unorm) {
            r.load(FieldGPU.SceneBuilder.rh1(palette: palette))
            r.background = background
            self.renderer = r
        }
    }

    /// Upload the solid model (Machine tab). Keeps the current camera.
    public func loadMachine(_ model: RH1Model, overlays: Set<String>, theme: Theme) {
        guard let dev = device else { return }
        if solid == nil, let ctx = renderer?.ctx ?? (try? MetalContext()) {
            _ = dev
            solid = try? SolidRenderer(ctx: ctx, sampleCount: sampleCount)
        }
        guard let s = solid else { return }
        let b = MachineCAD.batches(model, overlays: overlays)
        s.load(opaque: b.opaque, transparent: b.transparent,
               floor: SolidScene.floor(color: MachineCAD.floorColor(theme)))
        let cam = solidView.camera
        let keepCamera = showMachine
        solidView = MachineCAD.view(preset: "iso", overlays: overlays, theme: theme)
        if keepCamera { solidView.camera = cam }
    }

    public override var acceptsFirstResponder: Bool { true }

    public override func mouseDown(with event: NSEvent) {
        lastDrag = event.locationInWindow
    }

    public override func mouseDragged(with event: NSEvent) {
        let p = event.locationInWindow
        let dx = Float(p.x - lastDrag.x), dy = Float(p.y - lastDrag.y)
        lastDrag = p
        if showMachine {
            solidView.camera.azimuth -= dx * 0.008
            solidView.camera.elevation = max(-1.45, min(1.45, solidView.camera.elevation + dy * 0.008))
            return
        }
        renderer?.camera.azimuth -= dx * 0.008
        renderer?.camera.elevation = max(-1.45, min(1.45,
            (renderer?.camera.elevation ?? 0) + dy * 0.008))
    }

    public override func scrollWheel(with event: NSEvent) {
        if showMachine {
            solidView.camera.distance = max(0.35, min(6.0,
                solidView.camera.distance * Float(1 - event.scrollingDeltaY * 0.01)))
            return
        }
        guard let r = renderer else { return }
        r.camera.distance = max(0.25, min(2.0,
            r.camera.distance * Float(1 - event.scrollingDeltaY * 0.01)))
    }

    public override func keyDown(with event: NSEvent) {
        if showMachine {
            let keep = solidView
            switch event.charactersIgnoringModifiers {
            case "1": solidView = SolidView.machine("front")
            case "2": solidView = SolidView.machine("top")
            case "3", "0": solidView = SolidView.machine("iso")
            case "4": solidView = SolidView.machine("detail")
            case "5": solidView = SolidView.machine("plate")
            case "s":
                solidView.cut.toggle(); solidView.cutFromDeg = -90; solidView.cutToDeg = 0
                solidView.cutZMin = 0; solidView.cutZMax = 0
            default: super.keyDown(with: event); return
            }
            solidView.background = keep.background
            solidView.ambTop = keep.ambTop; solidView.ambBottom = keep.ambBottom
            solidView.capTint = keep.capTint
            return
        }
        guard let r = renderer else { return }
        switch event.charactersIgnoringModifiers {
        case "1": r.camera = .front
        case "2": r.camera = .top
        case "3", "0": r.camera = .home
        case "o": r.camera.orthographic.toggle()
        default: super.keyDown(with: event)
        }
    }

    // Drag-and-drop, registered on the Metal view itself. SwiftUI's .onDrop
    // does not reliably reach an NSViewRepresentable that draws its own
    // content, which is why the first attempt at dropping an STL did nothing.
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        urlFrom(sender) != nil ? .copy : []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = urlFrom(sender) else { return false }
        onLoadRequest?(url)
        return true
    }

    private func urlFrom(_ sender: NSDraggingInfo) -> URL? {
        guard let items = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: nil) as? [URL] else { return nil }
        return items.first { ["stl", "pattern"].contains($0.pathExtension.lowercased()) }
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let r = renderer,
              let rp = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let cb = r.ctx.queue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rp) else { return }
        let aspect = Float(max(1, drawableSize.width) / max(1, drawableSize.height))
        if showMachine, let s = solid {
            s.encode(into: enc, view: solidView, aspect: aspect)
        } else {
            r.encode(into: enc, aspect: aspect)
        }
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}

struct LiveViewportRepresentable: NSViewRepresentable {
    let theme: Theme
    let doc: Document
    func makeNSView(context: Context) -> NSView {
        guard let ctx = try? MetalContext() else {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.black.cgColor
            return v
        }
        let v = ViewportMTKView.make(
            ctx: ctx,
            palette: theme.isDark ? FieldGPU.SceneBuilder.Palette()
                                  : FieldGPU.SceneBuilder.Palette.light,
            background: theme.viewportBackground)
        v.onLoadRequest = { [weak doc] url in
            Task { @MainActor in doc?.load(url: url) }
        }
        doc.viewport = v
        if doc.mesh != nil { Task { @MainActor in doc.applyOverlays() } }
        if doc.state.mode == .machine { Task { @MainActor in doc.enterMachine() } }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Owns the mutable state the live app needs. Views stay pure functions of a
/// value (law L1); the APP owns the state, not the views.
@MainActor
public final class Document: ObservableObject {
    @Published public var state: AppState
    public private(set) var mesh: Mesh?
    public private(set) var fits = true
    weak var viewport: ViewportMTKView?
    /// Cached compile products, so overlay toggles are instant.
    var fieldMagnitude: [Double]?
    var fieldLattice: FieldLattice?
    var trapPoints: [(position: Vec3, depth: Double)] = []
    var potential: [Double]?
    var driveVector: [Complex]?
    var elements: [Element] = []
    var sim: ParticleSim?
    var matterGain: Double = 1
    var chordList: [MatrixPencil.Chord] = []
    var chordGates: [Scan.Gate] = []
    var patternName: String?

    public init(state: AppState) { self.state = state }

    public func load(url: URL) {
        if url.pathExtension.lowercased() == "pattern" {
            loadPattern(url: url)
            return
        }
        do {
            let raw = try STL.read(contentsOf: url)
            // STLs are conventionally millimetres; this app works in metres.
            let scaled = Mesh(triangles: raw.triangles.map {
                Triangle($0.a * 0.001, $0.b * 0.001, $0.c * 0.001)
            })
            adopt(scaled, name: url.lastPathComponent)
        } catch {
            state.statusLine = "could not read \(url.lastPathComponent): \(error)"
        }
    }

    public func adopt(_ raw: Mesh, name: String) {
        let volume = RH1.preset().buildVolume
        let placed = raw.placed(in: volume)
        mesh = placed.mesh
        fits = placed.fits
        let b = placed.mesh.bounds
        let size = b.max - b.min
        let vol = placed.mesh.signedVolume
        state.objects = [.init(
            name: name, material: state.material,
            detail: String(format: "Ø%.0f × %.0f mm · %.1f cm³",
                           max(size.x, size.y) * 1000, size.z * 1000, vol * 1e6),
            selected: true)]
        state.statusLine = placed.fits
            ? "\(placed.mesh.triangles.count) triangles · fits build volume"
            : String(format: "%d triangles · SCALED %.2f× to fit",
                     placed.mesh.triangles.count, placed.scale)
        applyOverlays()
    }

    /// Load a `.pattern`. Provenance is enforced at the decoder (G17): a chord
    /// without a provenance tag REJECTS the file rather than defaulting to
    /// "measured", and the split is reported rather than hidden.
    public func loadPattern(url: URL) {
        do {
            let pat = try PatternFile.decode(Data(contentsOf: url))
            chordList = pat.chords.map { rec in
                MatrixPencil.Chord(
                    pole: Complex(rec.p[0], rec.p[1]),
                    portVector: rec.r.map { Complex($0[0], $0[1]) },
                    weight: rec.weight,
                    provenance: rec.provenance == "inferred" ? .inferred : .measured)
            }
            // Gate ring reconstructed from the port count.
            let n = chordList.first?.portVector.count ?? 0
            let R = RH1.preset().buildVolume.radius * 0.92
            let H = RH1.preset().buildVolume.height
            chordGates = (0..<n).map { i in
                let a = 2 * Double.pi * Double(i) / Double(max(1, n))
                return Scan.Gate(position: Vec3(R * cos(a), R * sin(a),
                                                H * (0.3 + 0.4 * Double(i % 3) / 2)),
                                 normal: Vec3(-cos(a), -sin(a), 0))
            }
            patternName = url.lastPathComponent
            state.overlays.insert("chords")
            let m = pat.meta.counts.measured, inf = pat.meta.counts.inferred
            state.statusLine = "\(url.lastPathComponent): \(chordList.count) chords "
                + "(\(m) measured / \(inf) inferred) · "
                + "Green's fn \(pat.meta.reconstruction.greensFunction)"
            state.inspector = [
                .init(title: "Pattern", rows:
                    [("file", url.lastPathComponent),
                     ("chords", "\(chordList.count)"),
                     ("measured", "\(m)"),
                     ("inferred", "\(inf)"),
                     ("buildable", "\(pat.buildableChords.count)"),
                     ("Green's fn", pat.meta.reconstruction.greensFunction),
                     ("rung", pat.meta.reconstruction.rung)]
                    + chordList.prefix(5).enumerated().map { i, c in
                        ("chord \(i)", String(format: "%.0f Hz  Q %.0f",
                                              c.frequencyHz, c.qFactor))
                    }),
            ] + state.inspector.filter { $0.title != "Pattern" }
            applyOverlays()
        } catch {
            state.statusLine = "REJECTED \(url.lastPathComponent): \(error)"
        }
    }

    public func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an STL or .pattern"
        if panel.runModal() == .OK, let url = panel.url { load(url: url) }
    }

    // ---- real behaviour behind the controls -------------------------------

    public func actions() -> AppActions {
        var a = AppActions()
        a.setMode = { [weak self] m in Task { @MainActor in
            guard let self else { return }
            let wasMachine = self.state.mode == .machine
            self.state.mode = m
            self.state.statusLine = "\(m.name) mode"
            if m == .machine { self.enterMachine() }
            else if wasMachine { self.leaveMachine() }
        } }
        a.toggleOverlay = { [weak self] name in Task { @MainActor in
            guard let self else { return }
            if self.state.overlays.contains(name) { self.state.overlays.remove(name) }
            else { self.state.overlays.insert(name) }
            if name.hasPrefix("cad.") { self.refreshMachine() } else { self.applyOverlays() }
        } }
        a.toggleMachineView = { [weak self] in Task { @MainActor in
            guard let self else { return }
            self.state.machineView.toggle()
            self.state.statusLine = self.state.machineView
                ? "Machine View — reconstruction, not ground truth"
                : "God View — simulator ground truth"
        } }
        a.setMaterial = { [weak self] m in Task { @MainActor in
            guard let self else { return }
            self.state.material = m
            if !self.state.objects.isEmpty { self.state.objects[0].material = m }
        } }
        a.setFrame = { [weak self] f in Task { @MainActor in
            guard let self else { return }
            self.state.frame = max(0, min(self.state.frameCount, f))
            self.state.simTimeMs = Double(self.state.frame) * 0.05
        } }
        a.step = { [weak self] d in Task { @MainActor in
            guard let self else { return }
            self.state.frame = max(0, min(self.state.frameCount, self.state.frame + d))
            self.state.simTimeMs = Double(self.state.frame) * 0.05
        } }
        a.play = { [weak self] in Task { @MainActor in
            self?.togglePlay()
        } }
        a.primaryAction = { [weak self] in Task { @MainActor in
            guard let self else { return }
            if self.state.mode == .machine { self.exportMachine() } else { self.runPrimary() }
        } }
        return a
    }

    // ---- Machine tab ------------------------------------------------------

    private var savedInspector: [AppState.InspectorSection]?
    private var savedRail: (String, Int, Int, String)?
    private var machineModel: RH1Model?

    func enterMachine() {
        savedInspector = state.inspector
        savedRail = (state.machineName, state.gateCount, state.elementCount, state.buildVolumeText)
        MachineCAD.applyRail(&state)
        if !state.overlays.contains("cad.glass") { state.overlays.insert("cad.glass") }
        refreshMachine()
        viewport?.showMachine = true
        state.inspector = MachineCAD.inspector(machineModel ?? MachineCAD.model)
        state.statusLine = "RH-1 solid model · drag orbit · scroll zoom · S section · 1 front · 2 top · 3 iso · 4 detail · 5 plate"
    }

    func leaveMachine() {
        viewport?.showMachine = false
        if let s = savedInspector { state.inspector = s }
        if let r = savedRail {
            state.machineName = r.0; state.gateCount = r.1
            state.elementCount = r.2; state.buildVolumeText = r.3
        }
    }

    func refreshMachine() {
        let door = state.overlays.contains("cad.door")
        if machineModel == nil || (machineModel!.design.doorAngleDeg > 0) != door {
            machineModel = door ? RH1Model(design: MachineCAD.design(doorOpen: true)) : MachineCAD.model
        }
        viewport?.loadMachine(machineModel!, overlays: state.overlays, theme: state.theme)
        if state.overlays.contains("cad.section") {
            viewport?.solidView.cut = true
            viewport?.solidView.cutFromDeg = -90; viewport?.solidView.cutToDeg = 0
        } else {
            viewport?.solidView.cut = false
        }
    }

    func exportMachine() {
        let m = machineModel ?? MachineCAD.model
        let dir = URL(fileURLWithPath: "cad-out")
        state.busy = "Exporting…"
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            _ = try CADExport.writeSTL(m, to: dir.appendingPathComponent("stl"))
            try CADExport.writeOBJ(m, to: dir.appendingPathComponent("rh1.obj"))
            try CADExport.writeParams(m, to: dir.appendingPathComponent("rh1_params.json"))
            try CADExport.drawingSVG(m).write(to: dir.appendingPathComponent("rh1_general_arrangement.svg"),
                                              atomically: true, encoding: .utf8)
            state.statusLine = "exported \(m.parts.count) parts → \(dir.path) (STL, OBJ, params, drawing)"
        } catch {
            state.statusLine = "export failed: \(error)"
        }
        state.busy = nil
    }

    private var timer: Timer?

    func togglePlay() {
        state.isPlaying.toggle()
        timer?.invalidate()
        guard state.isPlaying else { timer = nil; return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
            Task { @MainActor in
                guard self.state.isPlaying else { return }
                self.state.frame = (self.state.frame + 1) % max(1, self.state.frameCount)
                self.state.simTimeMs = Double(self.state.frame) * 0.05
                if self.sim != nil && self.state.overlays.contains("matter") {
                    // forceGain is a DISPLAY scaling, not physics — drive
                    // amplitudes are not in SI yet (known defect).
                    let gain = self.matterGain
                    for _ in 0..<6 { self.sim!.step(dt: 2e-4, forceGain: gain) }
                    let c = self.sim!.counts
                    self.state.buildPercent =
                        Double(c.trapped) / Double(max(1, self.sim!.particles.count)) * 100
                    self.state.statusLine = String(
                        format: "matter: %d feedstock · %d in transit · %d trapped",
                        c.feedstock, c.inTransit, c.trapped)
                    self.applyOverlays()
                }
            }
        }
    }

    func applyOverlays() {
        let want = state.overlays
        let showField = want.contains("field") && fieldMagnitude != nil
        let showTraps = want.contains("traps") && !trapPoints.isEmpty
        let showMatter = want.contains("matter") && sim != nil
        let showChords = want.contains("chords") && !chordList.isEmpty
        var showBoundary: (elements: [Element], drive: [Complex])? = nil
        if want.contains("boundary"), let d = driveVector, !elements.isEmpty {
            showBoundary = (elements, d)
        }
        viewport?.setScene(
            object: want.contains("solid") ? mesh : nil, fits: fits,
            fieldMagnitude: showField ? fieldMagnitude : nil,
            fieldLattice: showField ? fieldLattice : nil,
            traps: showTraps ? trapPoints : [],
            particles: showMatter ? sim : nil,
            boundary: showBoundary,
            chords: showChords ? (chordGates, chordList) : nil)

        if let s = sim, want.contains("matter") {
            let c = s.counts
            state.buildPercent = Double(c.trapped) / Double(max(1, s.particles.count)) * 100
        }

        let backed: Set<String> = ["solid", "field", "traps", "matter",
                                   "boundary", "chords"]
        let live = want.intersection(backed)
        let notWired = want.subtracting(backed)
        var notes: [String] = []
        if want.contains("field") && fieldMagnitude == nil { notes.append("field: compile first") }
        if want.contains("traps") && trapPoints.isEmpty { notes.append("traps: compile first") }
        if want.contains("matter") && sim == nil { notes.append("matter: compile first") }
        if want.contains("boundary") && driveVector == nil { notes.append("boundary: compile first") }
        if want.contains("chords") && chordList.isEmpty { notes.append("chords: load a .pattern") }
        if !notWired.isEmpty {
            notes.append("not yet wired: \(notWired.sorted().joined(separator: ", "))")
        }
        state.statusLine = "overlays: \(live.sorted().joined(separator: ", "))"
            + (notes.isEmpty ? "" : "  ·  " + notes.joined(separator: "  ·  "))
    }

    /// Compile really runs the inverse solver against the loaded object.
    func runPrimary() {
        guard state.busy == nil else { return }
        guard let mesh else {
            state.statusLine = "load an object first"
            return
        }
        guard state.mode != .scan else {
            state.statusLine = "Scan runs FDTD and is CLI-only for now: `fieldc scan`"
            return
        }
        state.busy = "Compiling…"
        let material = state.material
        Task.detached(priority: .userInitiated) {
            let t0 = Date()
            let preset = RH1.preset()
            let f = 40_000.0
            let lambda = preset.medium.wavelength(at: f)
            let inset = 2 * lambda, sp = lambda / 2
            let R = preset.buildVolume.radius
            let lat = FieldLattice(
                origin: Vec3(-R, -R, inset), spacing: sp,
                nx: Int((2 * R / sp).rounded(.down)) + 1,
                ny: Int((2 * R / sp).rounded(.down)) + 1,
                nz: Int(((preset.buildVolume.height - 2 * inset) / sp).rounded(.down)) + 1)
            let prop = Propagator(elements: preset.elements, lattice: lat,
                                  frequency: f, medium: preset.medium,
                                  gateCount: preset.gateCount)
            // Control points on the object surface, chosen by FARTHEST-POINT
            // sampling so they actually span the shape. Striding over triangle
            // storage order (the previous version) samples mesh topology, not
            // geometry, and clusters wherever the exporter happened to order.
            let b = mesh.bounds
            let centre = (b.min + b.max) / 2
            let cands = mesh.triangles.map(\.centroid)
            var picked: [Vec3] = [cands[0]]
            let wanted = 6
            while picked.count < wanted && picked.count < cands.count {
                var best = cands[0], bestD = -1.0
                for c in cands {
                    let d = picked.map { ($0 - c).length }.min() ?? 0
                    if d > bestD { bestD = d; best = c }
                }
                picked.append(best)
            }
            // TWIN TRAPS, not foci. A focus is a pressure ANTINODE; a solid in
            // air has positive contrast and traps at NODES, so compiling foci
            // onto the surface asks for a field that pushes matter away from it.
            let targets = picked.map {
                InverseSolver.ControlPoint(position: $0, targetAmplitude: 1)
            }
            let drive = InverseSolver.solve(propagator: prop, points: targets,
                                            method: .gspat, iterations: 80,
                                            trap: .twinTrap)
            let field = prop.forward(drive)
            let mean = field.reduce(0.0) { $0 + $1.magnitude } / Double(field.count)
            // Overlay products, computed once here so toggling a chip is instant.
            let magnitude = field.map(\.magnitude)
            let gork = Gorkov(medium: preset.medium, particle: .pla())
            let U = gork.potentialField(propagator: prop, drive: drive)
            // Show only the significant wells. Every driven chamber has a
            // lambda/2 node lattice throughout — thousands of shallow minima —
            // so displaying all of them shows the ambient standing wave, not
            // the compiled result, which is what made the overlay look random.
            let allTraps = Gorkov.findTraps(U: U, lattice: lat, limit: 4000)
            let deepest = allTraps.first?.depth ?? 0
            let found = allTraps.filter { $0.depth >= 0.45 * deepest }
            // How close did the compiled traps land to what was asked for?
            let missDistances = picked.map { p in
                found.map { ($0.position - p).length }.min() ?? .infinity
            }
            let medianMiss = missDistances.sorted()[missDistances.count / 2]
            let lambdaHere = preset.medium.wavelength(at: f)
            var seeded = ParticleSim(potential: U, lattice: lat, medium: preset.medium)
            seeded.seedDelivered(count: 900)
            let seedGain = seeded.levitationGain(ratio: 3)
            let els = preset.elements
            var gain = 0.0
            for t in targets {
                gain += prop.pressure(at: t.position, drive: drive).magnitude
            }
            gain = mean > 0 ? gain / Double(targets.count) / mean : 0
            let secs = Date().timeIntervalSince(t0)
            await MainActor.run {
                self.fieldMagnitude = magnitude
                self.fieldLattice = lat
                self.trapPoints = found
                self.potential = U
                self.driveVector = drive
                self.elements = els
                self.sim = seeded
                self.matterGain = seedGain
                self.state.overlays.insert("field")
                self.state.overlays.insert("traps")
                self.state.overlays.insert("matter")
                self.state.busy = nil
                self.state.frameCount = 240
                self.state.statusLine = String(
                    format: "compiled %d twin traps · %d significant wells · "
                          + "median miss %.1f mm (%.2f lambda) · %.1fs",
                    targets.count, found.count, medianMiss * 1000,
                    medianMiss / lambdaHere, secs)
                self.state.inspector = [
                    .init(title: "Compile", rows: [
                        ("material", material),
                        ("method", "GS-PAT"),
                        ("control points", "\(targets.count)"),
                        ("gates", "\(preset.gateCount)"),
                        ("focus gain", String(format: "%.2f×", gain)),
                        ("lattice", "\(lat.count) pts"),
                        ("elapsed", String(format: "%.2fs", secs)),
                        ("trap kind", "twin (node)"),
                        ("wells shown", "\(found.count) of \(allTraps.count)"),
                        ("median miss", String(format: "%.1f mm", medianMiss * 1000)),
                    ]),
                ] + self.state.inspector.filter { $0.title != "Compile" }
                _ = centre
                self.applyOverlays()
            }
        }
    }

    public func clear() {
        mesh = nil
        fieldMagnitude = nil; fieldLattice = nil; trapPoints = []
        potential = nil; driveVector = nil; elements = []; sim = nil
        chordList = []; chordGates = []; patternName = nil
        state.objects = []
        state.statusLine = "no object loaded"
        viewport?.setScene(object: nil, fits: true)
    }
}

/// The live shell: the same chrome the screenshot harness renders, with a real
/// Metal view where the still image would be.
public struct LiveAppShell: View {
    @ObservedObject var doc: Document
    var s: AppState { doc.state }
    public init(_ doc: Document) { self.doc = doc }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Toolbar(s: s, a: doc.actions())
                HStack(spacing: 8) {
                    Button("Load STL…") { doc.openPanel() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    if !s.objects.isEmpty {
                        Button("Clear") { doc.clear() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(.trailing, 14)
                .background(s.theme.panel)
            }
            Divider().overlay(s.theme.stroke)
            HStack(spacing: 0) {
                ObjectRail(s: s, a: doc.actions()).frame(width: 240)
                Divider().overlay(s.theme.stroke)
                ZStack(alignment: .topLeading) {
                    LiveViewportRepresentable(theme: s.theme, doc: doc)
                    HStack(spacing: 6) {
                        if s.mode == .machine {
                            ForEach(MachineCAD.chips, id: \.self) { c in
                                OverlayChip(name: c, on: s.overlays.contains("cad." + c),
                                            theme: s.theme,
                                            action: doc.actions().toggleOverlay.map { f in
                                                { @Sendable (n: String) in f("cad." + n) } })
                            }
                        } else {
                            ForEach(["field", "traps", "matter", "solid",
                                     "boundary", "chords"], id: \.self) { c in
                                OverlayChip(name: c, on: s.overlays.contains(c),
                                            theme: s.theme,
                                            action: doc.actions().toggleOverlay)
                            }
                        }
                        Spacer()
                        Text(s.mode == .machine
                             ? "drag orbit · scroll zoom · S section · 1 front · 2 top · 3 iso · 4 detail · 5 plate"
                             : "drop an STL here · drag orbit · scroll zoom · 1 front · 2 top · 3 home")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().overlay(s.theme.stroke)
                Inspector(s: s).frame(width: 300)
            }
            Divider().overlay(s.theme.stroke)
            TransportBar(s: s, a: doc.actions())
        }
        .background(s.theme.background)
        .foregroundStyle(s.theme.text)
        .font(.system(size: 12))
        .environment(\.colorScheme, s.theme.isDark ? .dark : .light)
    }
}
