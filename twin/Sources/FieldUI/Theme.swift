import SwiftUI

/// Colour tokens. §16.4: no literal colours in views — a theme that lives in
/// scattered literals cannot be screenshot-tested in both modes.
public struct Theme: Sendable {
    public var isDark: Bool
    public var background: Color
    public var panel: Color
    public var panelAlt: Color
    public var stroke: Color
    public var text: Color
    public var textDim: Color
    public var accent: Color
    public var accentText: Color
    public var good: Color
    public var warn: Color
    public var bad: Color
    public var viewportBackground: SIMD4<Double>

    public static let dark = Theme(
        isDark: true,
        background: Color(red: 0.086, green: 0.090, blue: 0.102),
        panel: Color(red: 0.125, green: 0.131, blue: 0.145),
        panelAlt: Color(red: 0.157, green: 0.165, blue: 0.180),
        stroke: Color(red: 0.235, green: 0.243, blue: 0.263),
        text: Color(red: 0.902, green: 0.910, blue: 0.925),
        textDim: Color(red: 0.545, green: 0.561, blue: 0.596),
        accent: Color(red: 0.35, green: 0.72, blue: 0.62),
        accentText: Color(red: 0.04, green: 0.09, blue: 0.08),
        good: Color(red: 0.42, green: 0.78, blue: 0.55),
        warn: Color(red: 0.90, green: 0.72, blue: 0.35),
        bad: Color(red: 0.87, green: 0.42, blue: 0.42),
        viewportBackground: SIMD4<Double>(0.055, 0.06, 0.072, 1))

    public static let light = Theme(
        isDark: false,
        background: Color(red: 0.949, green: 0.945, blue: 0.933),
        panel: Color(red: 0.984, green: 0.980, blue: 0.969),
        panelAlt: Color(red: 0.925, green: 0.918, blue: 0.902),
        stroke: Color(red: 0.824, green: 0.812, blue: 0.788),
        text: Color(red: 0.110, green: 0.110, blue: 0.110),
        textDim: Color(red: 0.435, green: 0.435, blue: 0.427),
        accent: Color(red: 0.16, green: 0.47, blue: 0.40),
        accentText: Color.white,
        good: Color(red: 0.20, green: 0.50, blue: 0.30),
        warn: Color(red: 0.60, green: 0.45, blue: 0.10),
        bad: Color(red: 0.65, green: 0.20, blue: 0.20),
        viewportBackground: SIMD4<Double>(0.97, 0.965, 0.95, 1))
}

public struct AppMode: Sendable, Hashable {
    public let name: String
    public static let scan = AppMode(name: "Scan")
    public static let compile = AppMode(name: "Compile")
    public static let build = AppMode(name: "Build")
    public static let inspect = AppMode(name: "Inspect")
    /// The RH-1 solid model — geometry the simulation modes are defined on.
    public static let machine = AppMode(name: "Machine")
    public static let all: [AppMode] = [.scan, .compile, .build, .inspect, .machine]
}

/// Interaction handlers. All optional and all defaulting to nil.
///
/// This is how the shell stays a pure function of `AppState` for the screenshot
/// registry (law L1) AND becomes interactive in the live window: screenshots
/// pass no actions and render exactly as before; the app passes real closures
/// and the same controls become buttons. Without this the two would be separate
/// view trees, and the screenshots would stop being evidence about the app.
public struct AppActions: Sendable {
    public var setMode: (@Sendable (AppMode) -> Void)?
    public var toggleOverlay: (@Sendable (String) -> Void)?
    public var toggleMachineView: (@Sendable () -> Void)?
    public var primaryAction: (@Sendable () -> Void)?
    public var setMaterial: (@Sendable (String) -> Void)?
    public var setFrame: (@Sendable (Int) -> Void)?
    public var play: (@Sendable () -> Void)?
    public var step: (@Sendable (Int) -> Void)?
    public var selectObject: (@Sendable (UUID) -> Void)?
    public init() {}
}

/// Everything a screen needs to render, as a plain value (§20 law L1).
/// No view owns state; no view computes physics. This is what makes any screen
/// renderable headlessly from a literal fixture.
public struct AppState: Sendable {
    public var theme: Theme = .dark
    public var mode: AppMode = .compile
    public var machineName = "RH-1"
    public var material = "PLA"
    public var gateCount = 24
    public var elementCount = 4200
    public var buildVolumeText = "Ø280 × 300 mm"
    public var wavelengthText = "λ 8.575 mm · node 4.287 mm"
    public var objects: [ObjectRow] = []
    public var machineView = false        // Machine View vs God View (§16.2)
    public var overlays: Set<String> = ["field"]
    public var frame: Int = 0
    public var frameCount: Int = 240
    public var simTimeMs: Double = 0
    public var buildPercent: Double = 0
    public var overspillPercent: Double = 0
    public var statusLine = "ready"
    public var inspector: [InspectorSection] = []
    public var viewport: CGImage? = nil
    public var isPlaying = false
    public var busy: String? = nil
    public var materials = ["PLA", "Nylon", "PETG", "Glass", "Aluminium"]

    public init() {}

    public struct ObjectRow: Sendable, Identifiable {
        public var id = UUID()
        public var name: String
        public var material: String
        public var detail: String
        public var selected: Bool
        public init(name: String, material: String, detail: String, selected: Bool = false) {
            self.name = name; self.material = material
            self.detail = detail; self.selected = selected
        }
    }

    public struct InspectorSection: Sendable, Identifiable {
        public var id = UUID()
        public var title: String
        public var rows: [(String, String)]
        public init(title: String, rows: [(String, String)]) {
            self.title = title; self.rows = rows
        }
    }
}
