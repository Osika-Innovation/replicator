import SwiftUI
import CoreGraphics

/// THE screenshot registry (§21).
///
/// A UI state that is not in this registry does not ship. Adding a panel means
/// adding a scene; the contact sheet is what a reviewer — human or agent —
/// looks at to see the whole application in one image.
public enum SceneRegistry {

    public struct Scene: Sendable {
        public let id: String
        public let description: String
        public let camera: String        // which machine view the viewport shows
        public let make: @Sendable (Theme) -> AppState
        /// A `SolidView.machine` preset: when set, the viewport is the RH-1
        /// solid model (Machine tab) instead of the build-volume view.
        public var solid: String? = nil
    }

    public static var all: [Scene] { simulation + machine }

    public static let simulation: [Scene] = [
        Scene(id: "empty", description: "Empty state — the machine alone",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.statusLine = "no object loaded"
            s.inspector = machineSections()
            return s
        }),

        Scene(id: "imported", description: "STL imported and placed",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.objects = [.init(name: "cup.stl", material: "PLA",
                               detail: "Ø72 × 95 mm · 41 cm³", selected: true)]
            s.statusLine = "object fits build volume"
            s.inspector = machineSections()
            return s
        }),

        Scene(id: "compiled", description: "Compile complete, .fcode emitted",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.objects = [.init(name: "cup.stl", material: "PLA",
                               detail: "Ø72 × 95 mm · 41 cm³", selected: true)]
            s.overlays = ["field", "traps"]
            s.frameCount = 240
            s.statusLine = "compiled · residual 3.1e-3 · 240 frames"
            s.inspector = machineSections() + [
                .init(title: "Solve", rows: [
                    ("method", "GS-PAT"), ("iterations", "80"),
                    ("residual", "3.1e-3"), ("phase bits", "9"),
                ])]
            return s
        }),

        Scene(id: "field-slice", description: "Field overlay, |p| on a slice plane",
              camera: "front", make: { theme in
            var s = AppState(); s.theme = theme
            s.overlays = ["field"]
            s.statusLine = "slice z = 150 mm · log-compressed"
            s.inspector = machineSections() + [
                .init(title: "Field", rows: [
                    ("carrier", "acoustic"), ("frequency", "40.0 kHz"),
                    ("verb", "ADD"), ("peak", "1.00 (norm.)"),
                ])]
            return s
        }),

        Scene(id: "build-midway", description: "Build in progress, matter forming",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .build
            s.objects = [.init(name: "cup.stl", material: "PLA",
                               detail: "Ø72 × 95 mm · 41 cm³", selected: true)]
            s.overlays = ["matter", "solid", "traps"]
            s.frame = 96; s.frameCount = 240
            s.simTimeMs = 12.4; s.buildPercent = 34; s.overspillPercent = 0.8
            s.statusLine = "S(f) error 0.21 · listening"
            s.inspector = machineSections() + [
                .init(title: "Matter", rows: [
                    ("feedstock", "PLA powder"), ("particle", "200 µm"),
                    ("in flight", "1,284"), ("latched", "48,910"),
                ])]
            return s
        }),

        Scene(id: "scan-running", description: "Scan mode, coded runs in progress",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .scan
            s.machineView = true
            s.overlays = ["boundary", "chords"]
            s.frame = 7; s.frameCount = 24
            s.statusLine = "run 7/24 · Welch–Costas · coverage 61%"
            s.inspector = machineSections() + [
                .init(title: "Scan", rows: [
                    ("probe code", "Welch–Costas"), ("runs", "7 / 24"),
                    ("reciprocity", "0.031 ✓"), ("chords", "18 measured"),
                    ("provenance", "18 measured / 0 inferred"),
                ])]
            return s
        }),

        Scene(id: "gate-report", description: "Physics acceptance gates",
              camera: "top", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .inspect
            s.statusLine = "all 10 gates passed · receipt written"
            s.inspector = [
                .init(title: "Gates", rows: [
                    ("G1 voxelizer", "0.40% ✓"), ("G2 energy", "0.71% ✓"),
                    ("G3 time of flight", "0.44% ✓"), ("G6 node spacing", "2.5e-5 ✓"),
                    ("G7 Gor'kov", "3.6e-7 ✓"), ("G9a placement", "1.79 mm ✓"),
                    ("G9b sidelobe", "−7.2 dB ⚠"), ("G-GPU vs CPU", "3.8e-6 ✓"),
                ])]
            return s
        }),

        Scene(id: "machine-view", description: "Machine View — reconstruction, not truth",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .inspect
            s.machineView = true
            s.overlays = ["solid", "boundary"]
            s.buildPercent = 100
            s.statusLine = "L1 DORT · coverage-weighted · 12% of volume unobserved"
            s.inspector = machineSections() + [
                .init(title: "Reconstruction", rows: [
                    ("rung", "L1 DORT"), ("Green's fn", "measured"),
                    ("held-out err", "11.4%"), ("unobserved", "12.0%"),
                    ("provenance", "measured only"),
                ])]
            return s
        }),
    ]

    /// Machine-tab scenes: the CAD model, closed, cut, and the plate face.
    public static let machine: [Scene] = [
        Scene(id: "machine-cad", description: "Machine tab — RH-1 solid model, closed",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .machine
            MachineCAD.applyRail(&s)
            s.overlays = ["cad.glass"]
            s.statusLine = "RH-1 free-standing · \(MachineCAD.model.parts.count) parts · drag orbit · S section"
            s.inspector = MachineCAD.inspector()
            return s
        }, solid: "iso"),
        Scene(id: "machine-section", description: "Machine tab — quarter section",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .machine
            MachineCAD.applyRail(&s)
            s.overlays = ["cad.section", "cad.glass", "cad.envelopes"]
            s.statusLine = "quarter section · caps hatched · base contents are envelopes only"
            s.inspector = MachineCAD.inspector()
            return s
        }, solid: "section-iso"),
        Scene(id: "machine-plate", description: "Machine tab — mid-up plate face",
              camera: "top", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .machine
            MachineCAD.applyRail(&s)
            s.overlays = ["cad.section"]
            let p = MachineCAD.model.pattern
            s.statusLine = "plate face · \(p.drilled.count) micro-horns drilled · \(p.subsumedCount) of 380 sites fall in slot voids"
            s.inspector = MachineCAD.inspector()
            return s
        }, solid: "plate"),
    ]

    /// Fixture rows for the simulated machine — the same numbers the live app
    /// reads from `RH1Freestanding.standard()` at launch.
    static func machineSections() -> [AppState.InspectorSection] {
        [.init(title: "Machine", rows: [
            ("preset", "RH-1 free-standing"), ("gates", "6 acoustic (3 throat piezos × 2 faces)"),
            ("build volume", "Ø380 × 460"), ("λ @ 40 kHz", "8.597 mm"),
        ]),
         .init(title: "Carrier", rows: [
            ("band", "30–75 kHz"), ("medium", "air 20 °C 50 % RH, 343.87 m/s"),
            ("walls", "plates, 3 image orders, R 0.90"),
            ("solver", "T0 port fields (GPU)"),
         ])]
    }
}
