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
    public var solidView = SolidView.machine("iso") { didSet { redraw() } }
    public var showMachine = false { didSet { redraw() } }
    private var lastDrag: NSPoint = .zero
    private var palette = FieldGPU.SceneBuilder.Palette()
    /// Set by the document model when an object is loaded or cleared.
    public var onLoadRequest: ((URL) -> Void)?

    /// The chamber chrome (both plates with every element, the glass, the
    /// arcade), built once: it does not change with the scene.
    private lazy var chrome = FieldGPU.SceneBuilder.rh1(palette: palette, design: RH1Design())
    /// The camera starts on the mold volume at the chamber centre; F toggles
    /// between that and the whole chamber.
    private var closeUp = true

    /// Compose the whole scene: machine chrome, the object, and whichever
    /// overlay layers are switched on. One upload; no per-frame readback.
    public func setScene(object: Mesh?, fits: Bool, layers: [SceneGeometry] = []) {
        guard let r = renderer else { return }
        var extra = SceneGeometry()
        for g in layers {
            extra.linePositions += g.linePositions
            extra.lineColors += g.lineColors
            extra.trianglePositions += g.trianglePositions
            extra.triangleColors += g.triangleColors
        }
        if let mesh = object {
            let g = FieldGPU.SceneBuilder.object(mesh, palette: palette, fits: fits)
            extra.linePositions += g.linePositions
            extra.lineColors += g.lineColors
            extra.trianglePositions += g.trianglePositions
            extra.triangleColors += g.triangleColors
        }
        r.load(chrome, object: extra)
        redraw()
    }

    /// Look at the mold volume (a 24 mm cube at the chamber centre) or at the
    /// whole chamber.
    private func frameMold() {
        guard let r = renderer else { return }
        let c = LiveMachine.centre
        r.camera.target = closeUp ? SIMD3<Float>(Float(c.x), Float(c.y), Float(c.z)) : OrbitCamera.home.target
        r.camera.distance = closeUp ? 0.085 : OrbitCamera.home.distance
    }

    /// Ask for one new frame. The view draws on demand, not on a clock:
    /// nothing on screen animates by itself, so every visible change comes
    /// from an event (camera, scene, mode, resize) that calls this. The
    /// continuous 60 Hz loop this replaces kept ~60% of the GPU busy
    /// redrawing an unchanged picture while the app sat idle.
    public func redraw() { needsDisplay = true }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        redraw()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        redraw()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        redraw()
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
        // Event-driven drawing (see `redraw()`).
        self.enableSetNeedsDisplay = true
        self.isPaused = true
        self.palette = palette
        self.registerForDraggedTypes([.fileURL])
        if let r = try? Renderer(ctx: ctx, pixelFormat: .bgra8Unorm) {
            r.background = background
            self.renderer = r
            r.load(chrome)
            frameMold()
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
        redraw()
    }

    public override func scrollWheel(with event: NSEvent) {
        if showMachine {
            solidView.camera.distance = max(0.35, min(6.0,
                solidView.camera.distance * Float(1 - event.scrollingDeltaY * 0.01)))
            return
        }
        guard let r = renderer else { return }
        r.camera.distance = max(0.03, min(2.0,
            r.camera.distance * Float(1 - event.scrollingDeltaY * 0.01)))
        redraw()
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
        case "1": r.camera = .front; frameMold()
        case "2": r.camera = .top; frameMold()
        case "3", "0": r.camera = .home; frameMold()
        case "f": closeUp.toggle(); frameMold()
        case "o": r.camera.orthographic.toggle()
        default: super.keyDown(with: event); return
        }
        redraw()
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
        return items.first { $0.pathExtension.lowercased() == "stl" }
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

/// The machine the live app simulates: the RH-1's two plates in open air, the
/// same `PlateArray.rh1` every `fieldc` verb drives.
enum LiveMachine {
    static let array = PlateArray.rh1()
    static let air = RH1Freestanding.roomAir
    static var centre: Vec3 { array.centre }
    /// The mold's probe box is ±12 mm round the chamber centre and the powder
    /// is released 2 mm inside it; an object is placed within ±9.5 mm.
    static let probeHalf = 12e-3
    static let fitHalf = 9.5e-3
    static let band = (lo: 50_000.0, hi: 100_000.0)
    /// Compute context for the engine (separate from the viewport's).
    nonisolated(unsafe) static let gpu: MetalContext? = try? MetalContext()

    /// Every element of both plates, in channel order (lower plate first).
    static let elementSites: [(x: Double, y: Double, z: Double, radius: Double)] = array.elements().map {
        (x: $0.position.x, y: $0.position.y, z: $0.position.z, radius: ($0.area / Double.pi).squareRoot())
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
    /// The shape the engine works on: sites on the object's surface and the
    /// segments joining neighbours.
    var sites: [Vec3] = []
    var segments: [(Vec3, Vec3)] = []
    /// The last compile (a mold of the object on the plates), kept so overlay
    /// toggles and the transport bar are instant.
    var mold: MoldOutcome?
    var wellDepth: [Double]?
    var driveAmplitude: [Double]?
    /// The last scan: the image on its grid and the voxels above half the peak.
    var scanGrid: FieldLattice?
    var scanImage: [Double]?
    var scanHot: [(x: Vec3, value: Double)] = []
    var scanRead: [Vec3] = []

    public init(state: AppState) { self.state = state }

    public func load(url: URL) {
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

    /// Place an object at the chamber centre, shrunk if it does not fit the
    /// mold's probe volume, and read the shape the engine will work on.
    public func adopt(_ raw: Mesh, name: String) {
        let rb = raw.bounds
        let size = rb.max - rb.min
        let (placed, scale) = meshInMold(raw, centre: LiveMachine.centre, fitHalf: LiveMachine.fitHalf)
        mesh = placed
        fits = scale == 1
        mold = nil; wellDepth = nil; driveAmplitude = nil
        scanGrid = nil; scanImage = nil; scanHot = []; scanRead = []
        sites = meshPoints(placed, count: 16, minSpacing: 2.5e-3)
        segments = meshSegments(joining: sites)
        let s = size * scale
        state.objects = [.init(
            name: name, material: state.material,
            detail: String(format: "%.1f × %.1f × %.1f mm · %d sites", s.x * 1000, s.y * 1000, s.z * 1000, sites.count),
            selected: true)]
        state.frame = 0; state.frameCount = 0; state.simTimeMs = 0; state.buildPercent = 0
        state.overlays.insert("solid")
        applyOverlays()
        state.statusLine = scale == 1
            ? "\(placed.triangles.count) triangles · fits the mold volume (±\(Int(LiveMachine.fitHalf * 1000 + 0.5)) mm) · \(sites.count) sites"
            : String(format: "%d triangles · SCALED %.2f× to fit the mold volume (±%.1f mm) · %d sites",
                     placed.triangles.count, scale, LiveMachine.fitHalf * 1000, sites.count)
    }

    public func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an STL"
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
                ? "Machine View — what the plates can hear (run Scan)"
                : "God View — simulator ground truth"
            self.applyOverlays()
        } }
        a.setMaterial = { [weak self] m in Task { @MainActor in
            guard let self else { return }
            self.state.material = m
            if !self.state.objects.isEmpty { self.state.objects[0].material = m }
        } }
        a.setFrame = { [weak self] f in Task { @MainActor in self?.showFrame(f) } }
        a.step = { [weak self] d in Task { @MainActor in
            guard let self else { return }
            self.showFrame(self.state.frame + d)
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
    private var machineModel: RH1Model?

    func enterMachine() {
        savedInspector = state.inspector
        if !state.overlays.contains("cad.glass") { state.overlays.insert("cad.glass") }
        refreshMachine()
        viewport?.showMachine = true
        state.inspector = MachineCAD.inspector(machineModel ?? MachineCAD.model)
        state.statusLine = "RH-1 solid model · drag orbit · scroll zoom · S section · 1 front · 2 top · 3 iso · 4 detail · 5 plate"
    }

    func leaveMachine() {
        viewport?.showMachine = false
        if let s = savedInspector { state.inspector = s }
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

    // ---- the build: the stepped powder, frame by frame ---------------------

    private var timer: Timer?

    /// Share of the powder within 1 mm of the shape in a frame.
    private func onShapeShare(_ xs: [Vec3]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return Double(xs.filter { shapeDistance($0, segments) <= 1e-3 }.count) / Double(xs.count)
    }

    func showFrame(_ f: Int) {
        guard let m = mold, !m.frames.isEmpty else { return }
        state.frame = max(0, min(m.frames.count - 1, f))
        let fr = m.frames[state.frame]
        state.simTimeMs = fr.t * 1000
        state.buildPercent = onShapeShare(fr.x) * 100
        applyOverlays()
        state.statusLine = String(format: "powder at %.1f s of %.0f s: %.0f%% on the shape",
                                  fr.t, m.frames.last!.t, state.buildPercent)
    }

    func togglePlay() {
        guard let m = mold, m.frames.count > 1 else {
            state.statusLine = "nothing to play: compile first"
            return
        }
        state.isPlaying.toggle()
        timer?.invalidate()
        guard state.isPlaying else { timer = nil; return }
        if state.frame >= m.frames.count - 1 { state.frame = 0 }
        if !state.overlays.contains("matter") { state.overlays.insert("matter") }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { _ in
            Task { @MainActor in
                guard self.state.isPlaying, let m = self.mold else { return }
                if self.state.frame >= m.frames.count - 1 {
                    self.state.isPlaying = false
                    self.timer?.invalidate(); self.timer = nil
                    return
                }
                self.showFrame(self.state.frame + 1)
            }
        }
    }

    func applyOverlays() {
        let want = state.overlays
        var layers: [SceneGeometry] = []
        var notes: [String] = []
        let probe = Vec3(LiveMachine.probeHalf, LiveMachine.probeHalf, LiveMachine.probeHalf)
        layers.append(FieldGPU.SceneBuilder.box(min: LiveMachine.centre - probe, max: LiveMachine.centre + probe,
                                                color: SIMD4<Float>(0.5, 0.6, 0.7, 0.35)))
        if state.machineView {
            // What the plates heard: the scan's image, nothing from ground truth.
            if scanHot.isEmpty { notes.append("machine view: run Scan first") }
            layers.append(FieldGPU.SceneBuilder.points(
                scanHot.map(\.x), colors: scanHot.map { FieldGPU.SceneBuilder.ramp($0.value) }, radius: 0.35e-3))
        } else {
            if want.contains("field") {
                if let d = wellDepth, let lat = mold?.lattice {
                    let zs = sites.map(\.z).reduce(0, +) / Double(max(1, sites.count))
                    let k = max(1, min(lat.nz - 2, Int(((zs - lat.origin.z) / lat.spacing).rounded())))
                    layers.append(FieldGPU.SceneBuilder.fieldSlice(magnitude: d, lattice: lat, axis: 2, sliceIndex: k))
                } else { notes.append("field: compile first") }
            }
            if want.contains("boundary") {
                if let a = driveAmplitude {
                    layers.append(FieldGPU.SceneBuilder.elementDrive(sites: LiveMachine.elementSites, amplitude: a))
                } else { notes.append("boundary: compile first") }
            }
            if want.contains("traps") {
                // The sites the engine works on; after a compile, brighter = a
                // larger share of the powder.
                let share = mold?.basinPerSite ?? []
                let peak = max(share.max() ?? 1, 1e-12)
                layers.append(FieldGPU.SceneBuilder.points(
                    sites, colors: sites.indices.map { i in
                        share.isEmpty ? SIMD4<Float>(0.4, 0.85, 0.75, 1) : FieldGPU.SceneBuilder.ramp(0.35 + 0.65 * share[i] / peak)
                    }, radius: 0.6e-3))
            }
            if want.contains("matter") {
                if let m = mold, !m.frames.isEmpty {
                    let xs = m.frames[max(0, min(m.frames.count - 1, state.frame))].x
                    layers.append(FieldGPU.SceneBuilder.points(
                        xs, colors: xs.map {
                            shapeDistance($0, segments) <= 1e-3 ? SIMD4<Float>(0.98, 0.72, 0.38, 1) : SIMD4<Float>(0.6, 0.63, 0.68, 0.7)
                        }, radius: 0.2e-3))
                } else { notes.append("matter: compile first") }
            }
            if want.contains("scan") {
                if scanHot.isEmpty { notes.append("scan: run Scan first") }
                layers.append(FieldGPU.SceneBuilder.points(
                    scanHot.map(\.x), colors: scanHot.map { FieldGPU.SceneBuilder.ramp($0.value) }, radius: 0.35e-3))
            }
        }
        viewport?.setScene(object: (want.contains("solid") && !state.machineView) ? mesh : nil, fits: fits, layers: layers)
        let shown = want.filter { !$0.hasPrefix("cad.") }.sorted().joined(separator: ", ")
        state.statusLine = "overlays: \(shown)" + (notes.isEmpty ? "" : "  ·  " + notes.joined(separator: "  ·  "))
    }

    private var busyTimer: Timer?
    private func beginBusy(_ verb: String) {
        let t0 = Date()
        state.busy = verb + "…"
        busyTimer?.invalidate()
        busyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard self.state.busy != nil else { return }
                self.state.busy = String(format: "%@ %d s", verb, Int(Date().timeIntervalSince(t0)))
            }
        }
    }
    private func endBusy() { busyTimer?.invalidate(); busyTimer = nil; state.busy = nil }

    /// Scan mode: the plates' gated pulse-echo scan of the object. Every other
    /// mode: compile a mold of it — one chord drive that makes the shape the
    /// only place the powder can rest — and step the powder through it.
    public func runPrimary() {
        guard state.busy == nil else { return }
        guard mesh != nil, !sites.isEmpty else {
            state.statusLine = "load an object first"
            return
        }
        guard let ctx = LiveMachine.gpu else {
            state.statusLine = "no Metal device: the engine needs the GPU"
            return
        }
        if state.mode == .scan { runScan(ctx) } else { runCompile(ctx) }
    }

    private func runCompile(_ ctx: MetalContext) {
        beginBusy("Compiling")
        let sites = self.sites, segments = self.segments
        let label = state.objects.first?.name ?? "object"
        let material = state.material
        Task.detached(priority: .userInitiated) {
            let t0 = Date()
            var setup = MoldSetup()
            setup.frameEvery = 0.1
            let result: Result<MoldOutcome, Error> = Result {
                try runMold(ctx: ctx, label: label, sites: sites, segments: segments,
                            chamber: .plates(LiveMachine.array), setup: setup, log: { line in
                    let short = String(line.trimmingCharacters(in: .whitespaces).prefix(150))
                    Task { @MainActor in self.state.statusLine = short }
                })
            }
            let secs = Date().timeIntervalSince(t0)
            await MainActor.run {
                self.endBusy()
                switch result {
                case .failure(let e):
                    self.state.statusLine = "compile failed: \(e)"
                case .success(let out):
                    self.mold = out
                    // Well depth below the landscape's top, clipped at its
                    // 98th percentile so a few deep wells do not black out the rest.
                    let uMax = out.potential.max() ?? 0
                    let depth = out.potential.map { uMax - $0 }
                    let cap = max(depth.sorted()[Int(Double(depth.count - 1) * 0.98)], 1e-300)
                    self.wellDepth = depth.map { min($0, cap) }
                    let ch = LiveMachine.array.channels
                    var amp = [Double](repeating: 0, count: ch)
                    for d in out.drives { for c in 0..<min(ch, d.count) { amp[c] += d[c].magnitudeSquared } }
                    self.driveAmplitude = amp.map { ($0 * out.power).squareRoot() }
                    for o in ["field", "traps", "matter"] { self.state.overlays.insert(o) }
                    self.state.frameCount = max(0, out.frames.count - 1)
                    let fair = 1 / Double(max(1, out.sites.count))
                    let watts = out.gates.first { $0.id == "G-E2" }?.measured ?? 0
                    let f = out.frequencies
                    self.state.inspector = [
                        .init(title: "Mold", rows: [
                            ("object", label),
                            ("powder", "\(material) Ø40 µm, 3000 grains"),
                            ("sites", "\(out.sites.count)"),
                            ("tones", String(format: "%d, %.0f–%.0f kHz", out.tones, (f.min() ?? 0) / 1000, (f.max() ?? 0) / 1000)),
                            ("drive", String(format: "%.2f m/s on the hardest-driven element", out.elementAmplitude.max() ?? 0)),
                            ("acoustic power", String(format: "%.0f W", watts)),
                            ("lift contrast", String(format: "%.2f", out.contrast)),
                            ("on the shape", String(format: "%.1f %%", 100 * out.basinOnShape)),
                            ("per site", String(format: "%.1f–%.1f %% (fair %.1f %%)",
                                                100 * (out.basinPerSite.min() ?? 0), 100 * (out.basinPerSite.max() ?? 0), 100 * fair)),
                            ("stepped grains", String(format: "%d of %d on the shape", out.captured, out.final.count)),
                            ("elapsed", String(format: "%.0f s", secs)),
                        ]),
                        .init(title: "Gates", rows: out.gates.map { g in
                            (g.id, String(format: "%.3g %@", g.measured, g.passed ? "✓" : "✗ FAILS"))
                        }),
                    ] + self.state.inspector.filter { !["Mold", "Gates"].contains($0.title) }
                    self.showFrame(out.frames.count - 1)
                    let failed = out.gates.filter { !$0.passed }.map(\.id)
                    self.state.statusLine = String(
                        format: "mold compiled in %.0f s: %.0f%% of the powder on the shape, sites %.1f–%.1f%% (fair %.1f%%)%@",
                        secs, 100 * out.basinOnShape, 100 * (out.basinPerSite.min() ?? 0),
                        100 * (out.basinPerSite.max() ?? 0), 100 * fair,
                        failed.isEmpty ? " · all gates pass" : " · FAILS " + failed.joined(separator: ", "))
                }
            }
        }
    }

    private func runScan(_ ctx: MetalContext) {
        guard let mesh else { return }
        beginBusy("Scanning")
        Task.detached(priority: .userInitiated) {
            let t0 = Date()
            // The object as the scan sees it: small rigid scatterers 1 mm
            // apart over its surface (Born), as `fieldc scan3d` models a wire.
            let object = meshPoints(mesh, count: 80, minSpacing: 1e-3, relax: false)
            let half = 14e-3, h = 0.7e-3
            let n = Int((2 * half / h).rounded()) + 1
            let c = LiveMachine.centre
            let grid = FieldLattice(origin: c - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
            let setup = ArrayScanSetup()
            let result: Result<[Double], Error> = Result {
                try scanImageArray(ctx: ctx, array: LiveMachine.array, object: object, subunit: 0.3e-3,
                                   grid: grid, setup: setup, log: { line in
                    let short = String(line.trimmingCharacters(in: .whitespaces).prefix(150))
                    Task { @MainActor in self.state.statusLine = short }
                })
            }
            let secs = Date().timeIntervalSince(t0)
            await MainActor.run {
                self.endBusy()
                switch result {
                case .failure(let e):
                    self.state.statusLine = "scan failed: \(e)"
                case .success(let I):
                    let tol = max(2e-3, 1.5 * h)
                    let sc = scanScore(image: I, grid: grid, object: object, tol: tol)
                    let pos = grid.positions
                    self.scanGrid = grid; self.scanImage = I
                    self.scanHot = I.indices.filter { I[$0] >= 0.5 }.map { (pos[$0], I[$0]) }
                    self.scanRead = extractShape(image: I, grid: grid, threshold: 0.5, spacing: 3e-3).sites
                    self.state.overlays.insert("scan")
                    self.state.inspector = [
                        .init(title: "Scan", rows: [
                            ("method", "gated pulse-echo, matched filter"),
                            ("band", String(format: "%.0f–%.0f kHz, %d frequencies", setup.sweep(on: LiveMachine.array).lo / 1000, setup.sweep(on: LiveMachine.array).hi / 1000, setup.sweep(on: LiveMachine.array).count)),
                            ("pulses", "\(setup.chords) random chords"),
                            ("scatterers", "\(object.count), Ø0.6 mm"),
                            ("grid", String(format: "±%.0f mm at %.1f mm (%d³)", half * 1000, h * 1000, n)),
                            ("recall", String(format: "%.0f %% within %.0f mm", 100 * sc.recall, tol * 1000)),
                            ("AUC", String(format: "%.3f", sc.auc)),
                            ("contrast", String(format: "%.1f×", sc.contrast)),
                            ("peak", String(format: "%.2f mm from the object", sc.peakDistance * 1000)),
                            ("sites read", "\(self.scanRead.count)"),
                            ("elapsed", String(format: "%.0f s", secs)),
                        ]),
                    ] + self.state.inspector.filter { $0.title != "Scan" }
                    self.applyOverlays()
                    self.state.statusLine = String(
                        format: "scanned in %.0f s: %.0f%% of the object imaged within %.0f mm, AUC %.3f, %d sites read",
                        secs, 100 * sc.recall, tol * 1000, sc.auc, self.scanRead.count)
                }
            }
        }
    }

    public func clear() {
        mesh = nil
        sites = []; segments = []
        mold = nil; wellDepth = nil; driveAmplitude = nil
        scanGrid = nil; scanImage = nil; scanHot = []; scanRead = []
        state.objects = []
        state.frame = 0; state.frameCount = 0; state.buildPercent = 0
        applyOverlays()
        state.statusLine = "no object loaded"
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
                            ForEach(["solid", "traps", "field", "matter",
                                     "boundary", "scan"], id: \.self) { c in
                                OverlayChip(name: c, on: s.overlays.contains(c),
                                            theme: s.theme,
                                            action: doc.actions().toggleOverlay)
                            }
                        }
                        Spacer()
                        Text(s.mode == .machine
                             ? "drag orbit · scroll zoom · S section · 1 front · 2 top · 3 iso · 4 detail · 5 plate"
                             : "drop an STL here · drag orbit · scroll zoom · 1 front · 2 top · 3 home · F chamber / mold")
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
