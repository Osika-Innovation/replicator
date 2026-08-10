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
    }

    public static let all: [Scene] = [
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

    static func machineSections() -> [AppState.InspectorSection] {
        [.init(title: "Machine", rows: [
            ("preset", "RH-1"), ("gates", "24 acoustic"),
            ("build volume", "Ø280 × 300"), ("λ @ 40 kHz", "8.575 mm"),
        ]),
         .init(title: "Carrier", rows: [
            ("band", "20–80 kHz"), ("medium", "air 343 m/s"),
            ("solver", "T0 propagator"),
         ])]
    }
}
