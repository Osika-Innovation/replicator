import Foundation

/// A small array that exists to test the propagator rather than a machine:
/// every transducer is its own gate.
public enum TestPresets {

    /// Single planar array — the half-space / "table" rung of the boundary
    /// ladder, licensed by Rayleigh-Sommerfeld.
    public static func singlePlate(n: Int = 16, frequency: Double = 40_000,
                                   medium: Medium = .air) -> MachinePreset {
        let lambda = medium.wavelength(at: frequency)
        let pitch = lambda / 2
        let extent = Double(n - 1) * pitch
        var elements: [Element] = []
        var gate = 0
        for j in 0..<n {
            for i in 0..<n {
                elements.append(Element(
                    position: Vec3(-extent / 2 + Double(i) * pitch,
                                   -extent / 2 + Double(j) * pitch, 0),
                    normal: Vec3(0, 0, 1), area: pitch * pitch,
                    surface: .panel, gateIndex: gate))
                gate += 1
            }
        }
        return MachinePreset(id: "single-plate-\(n)x\(n)",
                             displayName: "Single plate \(n)x\(n)",
                             elements: elements, gateCount: gate,
                             buildVolume: BuildVolume(radius: extent / 2, height: 0.10),
                             medium: medium)
    }
}
