import SwiftUI
import FieldCore
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

    /// The object every fixture shows: the default ring, as the live app
    /// describes it once loaded.
    static let ring = AppState.ObjectRow(name: "ring.stl", material: "PLA",
                                         detail: "17.0 × 17.0 × 1.0 mm · 16 sites", selected: true)

    /// Fixtures of the simulation modes. The mold's numbers are the default
    /// ring's (receipt `mold-ring-stl-sieve-rh1x192_2026-11-11T05-00-42Z`, the
    /// same run the live app makes); the live app shows its own run's.
    public static let simulation: [Scene] = [
        Scene(id: "empty", description: "Empty state — the machine alone",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.overlays = []
            s.statusLine = "no object loaded"
            s.inspector = machineSections()
            return s
        }),

        Scene(id: "imported", description: "STL loaded and placed in the mold volume",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.objects = [ring]
            s.statusLine = "960 triangles · fits the mold volume (±10 mm) · 16 sites"
            s.inspector = machineSections()
            return s
        }),

        Scene(id: "compiled", description: "Compile complete: a mold of the object",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.objects = [ring]
            s.overlays = ["solid", "traps", "field", "matter"]
            s.frame = 80; s.frameCount = 80; s.simTimeMs = 8000; s.buildPercent = 100
            s.statusLine = "mold compiled: 100% of the powder on the shape, sites 5.4–6.9% (fair 6.2%) · all gates pass"
            s.inspector = [moldSection, moldGates] + machineSections()
            return s
        }),

        Scene(id: "field-slice", description: "Field overlay: well depth on a slice through the sites",
              camera: "top", make: { theme in
            var s = AppState(); s.theme = theme
            s.objects = [ring]
            s.overlays = ["field", "traps"]
            s.frame = 80; s.frameCount = 80; s.simTimeMs = 8000; s.buildPercent = 100
            s.statusLine = "overlays: field, traps"
            s.inspector = [moldSection] + machineSections()
            return s
        }),

        Scene(id: "build-midway", description: "Build: the stepped powder part-way down",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .build
            s.objects = [ring]
            s.overlays = ["matter", "solid", "traps"]
            s.frame = 10; s.frameCount = 80
            s.simTimeMs = 1000; s.buildPercent = 47
            s.statusLine = "powder at 1.0 s of 8 s: 47% on the shape"
            s.inspector = [moldSection, moldGates] + machineSections()
            return s
        }),

        Scene(id: "scan-running", description: "Scan mode: the plates' pulse-echo image",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .scan
            s.objects = [ring]
            s.overlays = ["solid", "scan"]
            s.statusLine = "scanned in 37 s: 100% of the object imaged within 2 mm, AUC 0.990, 12 sites read"
            s.inspector = [scanSection] + machineSections()
            return s
        }),

        Scene(id: "gate-report", description: "Inspect: the last compile's gates",
              camera: "top", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .inspect
            s.objects = [ring]
            s.overlays = ["traps", "boundary"]
            s.frame = 80; s.frameCount = 80; s.simTimeMs = 8000; s.buildPercent = 100
            s.statusLine = "overlays: boundary, traps"
            s.inspector = [moldGates, moldSection]
            return s
        }),

        Scene(id: "machine-view", description: "Machine View — only what the plates heard",
              camera: "iso", make: { theme in
            var s = AppState(); s.theme = theme
            s.mode = .scan
            s.machineView = true
            s.objects = [ring]
            s.overlays = ["scan"]
            s.statusLine = "Machine View — what the plates can hear (run Scan)"
            s.inspector = [scanSection] + machineSections()
            return s
        }),
    ]

    static let moldSection = AppState.InspectorSection(title: "Mold", rows: [
        ("object", "ring.stl"), ("powder", "PLA Ø40 µm, 3000 grains"),
        ("sites", "16"), ("tones", "9, 53–97 kHz"),
        ("drive", "2.81 m/s rms per element"), ("acoustic power", "111 W"),
        ("lift contrast", "3.07"), ("on the shape", "100.0 %"),
        ("per site", "5.4–6.9 % (fair 6.2 %)"),
    ])
    static let moldGates = AppState.InspectorSection(title: "Gates", rows: [
        ("G-M1", "0.856 ✓"), ("G-M2", "1 ✓"), ("G-B0", "2.89e-14 ✓"), ("G-B1", "0.00891 ✓"),
    ])
    static let scanSection = AppState.InspectorSection(title: "Scan", rows: [
        ("method", "gated pulse-echo, matched filter"),
        ("band", "30–100 kHz, 320 frequencies"), ("pulses", "8 random chords"),
        ("grid", "±14 mm at 0.7 mm (41³)"),
        ("recall", "100 % within 2 mm"), ("AUC", "0.990"), ("contrast", "8.2×"),
    ])

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
            s.statusLine = "plate face · \(p.elements.count) driven elements · \(p.slotCenterlines.count) slot dashes on 12 arms"
            s.inspector = MachineCAD.inspector()
            return s
        }, solid: "plate"),
    ]

    /// The machine every mode simulates, as inspector rows: the RH-1's two
    /// plates in room air, read from `PlateArray.rh1` (the live app and the
    /// screenshot fixtures show the same rows).
    public static func machineSections() -> [AppState.InspectorSection] {
        let a = PlateArray.rh1()
        let air = RH1Freestanding.roomAir
        return [.init(title: "Machine", rows: [
            ("preset", "RH-1 free-standing"),
            ("plates", String(format: "2, %.0f mm apart, open air", a.gap * 1000)),
            ("elements", a.tones == nil
                ? String(format: "2 × %d, Ø%.0f mm pistons", a.perPlate, a.elementRadius * 2000)
                : String(format: "2 × %d resonant, Ø%.1f–%.1f mm", a.perPlate,
                         2000 * ((0..<a.channels).map { a.pistonRadius($0) }.min() ?? 0),
                         2000 * ((0..<a.channels).map { a.pistonRadius($0) }.max() ?? 0))),
            ("layout", String(format: "golden-angle spiral, r %.0f–%.1f mm", a.innerRadius * 1000, a.plateRadius * 1000)),
            ("mold volume", "24 mm cube at the centre"),
        ]),
         .init(title: "Carrier", rows: [
            ("mold band", "50–100 kHz, 9 tones"),
            ("scan band", "30–100 kHz, 320 frequencies"),
            ("medium", String(format: "air %.0f °C %.0f %% RH, %.2f m/s", air.air?.temperatureC ?? 20, air.air?.humidity ?? 50, air.soundSpeed)),
            ("walls", String(format: "plates, %d image orders, R %.2f", a.imageOrder, a.reflection)),
            ("solver", "matrix-free array field (GPU)"),
         ])]
    }
}
